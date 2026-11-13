/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Résolveur anime-sama 100% Dart, unique résolveur de l'application (Android
/// et desktop). Implémente [StreamResolver] directement — plus aucune dépendance
/// vers le wrapper Python.
///
/// Orchestre les modules purs : `animesama_domain`, `animesama_title_matcher`,
/// `animesama_seasons`, `animesama_embed_resolver`, `animesama_aniskip`,
/// `animesama_catalog_parser`. Le réseau passe par un [HttpFetcher] injectable.
library;

import 'animesama_aniskip.dart';
import 'animesama_catalog_parser.dart';
import 'animesama_domain.dart';
import 'animesama_embed_resolver.dart';
import 'animesama_http_client.dart';
import 'animesama_seasons.dart';
import 'animesama_title_matcher.dart';
import 'stream_resolver.dart';

/// Formate un timestamp Unix (secondes) en « HHhMM » heure locale.
/// Équivaut à `time.strftime("%Hh%M", localtime(ts))` du Python.
String _formatReleaseTime(int ts) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${hh}h$mm';
}

/// Résolveur anime-sama 100% Dart, seul résolveur de l'application.
/// Implémente [StreamResolver] (interface publique attendue par les providers).
class DartAnimeSamaResolver implements StreamResolver {
  final HttpFetcher fetch;

  /// Domaine résolu, mis en cache après la 1re résolution (comme `ensure_domain`).
  String? _domain;

  /// Cache en mémoire des MAL IDs résolus (optimisation instantanée pour AniSkip).
  final Map<String, int> _malIdBySlug = {};
  final Map<String, int> _malIdByTitle = {};

  /// Cache court et déduplication des requêtes parallèles sur les saisons et
  /// épisodes (évite les rafales N×N à l'ouverture d'une fiche multi-saisons).
  final Map<String, ({DateTime expiresAt, (String, List<RawSeason>) value})>
      _seasonsCache = {};
  final Map<String, Future<(String, List<RawSeason>)>> _inFlightSeasons = {};
  final Map<String, ({DateTime expiresAt, SeasonInfo value})>
      _seasonInfoCache = {};
  final Map<String, Future<SeasonInfo>> _inFlightSeasonInfo = {};
  final Map<String, String> _resolvedLiens = {};

  DartAnimeSamaResolver({required this.fetch});

  /// Résout (une fois) puis renvoie le domaine anime-sama courant.
  Future<String> _ensureDomain() async {
    return _domain ??= await resolveCurrentDomain(fetch);
  }

  bool _isVf(PlaybackLanguage language) => language == PlaybackLanguage.vf;

  // --- Saisons réelles (port de _seasons_for) --------------------------------

  /// Retourne (anime_url, saisons canoniques) ou lève [ResolveException].
  /// Déduplique les appels concurrents et met en cache 2 minutes pour éviter
  /// le throttling d'anime-sama lors du chargement des N saisons d'une fiche.
  Future<(String, List<RawSeason>)> _seasonsFor(String title) {
    final key = title.trim().toLowerCase();
    final now = DateTime.now();
    final cached = _seasonsCache[key];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return Future.value(cached.value);
    }
    final inFlight = _inFlightSeasons[key];
    if (inFlight != null) return inFlight;

    final future = _resolveSeasonsUncached(title).then((res) {
      _seasonsCache[key] = (
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        value: res,
      );
      return res;
    }).whenComplete(() {
      _inFlightSeasons.remove(key);
    });
    _inFlightSeasons[key] = future;
    return future;
  }

  Future<(String, List<RawSeason>)> _resolveSeasonsUncached(
    String title,
  ) async {
    final domain = await _ensureDomain();
    String? animeUrl;
    if (title.startsWith('http://') || title.startsWith('https://')) {
      animeUrl = title;
    } else if (title.startsWith('/catalogue/')) {
      animeUrl = 'https://$domain$title';
    } else {
      final found = await searchCatalogue(fetch, domain, title, vf: false);
      if (found != null) {
        animeUrl = found.url;
      } else {
        final slugCandidates = <String>[
          slugFromUrl('/catalogue/$title/'),
          title
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
              .replaceAll(RegExp(r'^-+|-+$'), ''),
        ];
        for (final slug in slugCandidates) {
          if (slug.isEmpty) continue;
          final directUrl = 'https://$domain/catalogue/$slug/';
          final testResp = await fetch(directUrl, headers: {
            ...kHeadersBase,
            'referer': 'https://$domain/catalogue/',
          });
          if (testResp.ok) {
            animeUrl = directUrl;
            break;
          }
        }
      }
    }
    if (animeUrl == null) {
      throw ResolveException('aucun anime correspondant a "$title"');
    }
    final resp = await fetch(animeUrl, headers: {
      ...kHeadersBase,
      'referer': 'https://$domain/catalogue/',
    });
    if (!resp.ok) {
      throw ResolveException('page anime indisponible (${resp.statusCode})');
    }

    // Extrait d'abord les saisons actives (hors commentaires JS /* */ / // et HTML <!-- -->).
    var raw = parseActiveSeasons(resp.body);
    var candidates = dedupeSeasons(raw.where(isRealSeason).toList());
    if (candidates.isEmpty) {
      raw = parseSeasons(resp.body);
      candidates = dedupeSeasons(raw.where(isRealSeason).toList());
    }

    // Vérifie toutes les candidates par lots sans arrêt anticipé sur un « trou »
    // (ex. OAV indisponible avant Kai dans Bleach, ou saison VOSTFR-only en VF).
    final hasEpisodesList = List<bool>.filled(candidates.length, false);
    const batchSize = 5;
    for (var start = 0; start < candidates.length; start += batchSize) {
      final end = (start + batchSize < candidates.length)
          ? start + batchSize
          : candidates.length;
      await Future.wait([
        for (var i = start; i < end; i++)
          _seasonHasAnyEpisodes(animeUrl, candidates[i]).then((ok) {
            hasEpisodesList[i] = ok;
          }),
      ]);
    }

    final real = <RawSeason>[
      for (var i = 0; i < candidates.length; i++)
        if (hasEpisodesList[i]) candidates[i],
    ];
    if (real.isEmpty) {
      throw const ResolveException('aucune saison avec episodes trouvee');
    }
    return (animeUrl, real);
  }

  /// URL complète d'une saison (concatène anime_url + chemin, réécrit VF).
  String _seasonUrl(String animeUrl, RawSeason s, bool vf) {
    var rel = s.url.trim().replaceAll(RegExp(r'^/+'), '');
    if (vf) {
      rel = rel.replaceAllMapped(
        RegExp(r'(^|/)vostfr(?=/|$)', caseSensitive: false),
        (m) => '${m[1]}vf',
      );
    }
    return '${animeUrl.replaceAll(RegExp(r'/+$'), '')}/$rel';
  }

  Future<SeasonInfo> _fetchSeasonInfoCached(String seasonUrl) {
    final key = seasonUrl.replaceAll(RegExp(r'/+$'), '').toLowerCase();
    final now = DateTime.now();
    final cached = _seasonInfoCache[key];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return Future.value(cached.value);
    }
    final inFlight = _inFlightSeasonInfo[key];
    if (inFlight != null) return inFlight;

    final future = fetchSeasonInfo(fetch, seasonUrl).then((info) {
      if (info.episodes.isNotEmpty) {
        _seasonInfoCache[key] = (
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          value: info,
        );
      }
      return info;
    }).whenComplete(() {
      _inFlightSeasonInfo.remove(key);
    });
    _inFlightSeasonInfo[key] = future;
    return future;
  }

  Future<Map<String, List<String>>> _fetchEpisodesCached(String seasonUrl) async {
    final info = await _fetchSeasonInfoCached(seasonUrl);
    return info.episodes;
  }

  Future<String> _resolveLien(
    String domain,
    String link,
    String? jeton,
    String seasonUrl,
  ) async {
    if (!link.startsWith('lien:')) return link;
    final cached = _resolvedLiens[link];
    if (cached != null) return cached;
    final id = link.substring('lien:'.length).trim();
    if (id.isEmpty) return link;
    try {
      final apiUrl =
          'https://$domain/api/lien.php?j=${Uri.encodeComponent(jeton ?? "")}&l=$id';
      final resp = await fetch(apiUrl, headers: {
        ...kHeadersBase,
        'referer': seasonUrl,
        'accept': '*/*',
      });
      if (!resp.ok) return link;
      final m = RegExp(r'''"u"\s*:\s*"([^"]+)"''').firstMatch(resp.body);
      if (m != null) {
        final realUrl = m.group(1)!.replaceAll(r'\/', '/');
        _resolvedLiens[link] = realUrl;
        return realUrl;
      }
    } catch (_) {}
    return link;
  }

  /// Vrai si la saison a au moins un épisode réellement jouable (URL par défaut
  /// ou son équivalent VF si absent par défaut).
  Future<bool> _seasonHasAnyEpisodes(String animeUrl, RawSeason s) async {
    try {
      final defaultUrl = _seasonUrl(animeUrl, s, false);
      final eps = await _fetchEpisodesCached(defaultUrl);
      if (playableEpisodeCount(eps) > 0) return true;

      if (s.url.toLowerCase().contains('vostfr')) {
        final vfUrl = _seasonUrl(animeUrl, s, true);
        if (vfUrl != defaultUrl) {
          final vfEps = await _fetchEpisodesCached(vfUrl);
          return playableEpisodeCount(vfEps) > 0;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Saison par index 1-based, ou `null` hors bornes. Port de `_pick_by_index`.
  RawSeason? _pickByIndex(List<RawSeason> seasons, int index) {
    if (index >= 1 && index <= seasons.length) return seasons[index - 1];
    return null;
  }

  // --- Méthodes publiques ----------------------------------------------------

  Future<List<AnimeSamaSeason>> listSeasons({
    required String title,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final (_, seasons) = await _seasonsFor(title);
    return [
      for (var i = 0; i < seasons.length; i++)
        AnimeSamaSeason(index: i + 1, name: seasons[i].name)
    ];
  }

  Future<List<int>> listEpisodes({
    required String title,
    required int seasonIndex,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final vf = _isVf(language);
    final (animeUrl, seasons) = await _seasonsFor(title);
    final season = _pickByIndex(seasons, seasonIndex);
    if (season == null) {
      throw ResolveException(
          'saison #$seasonIndex hors bornes (1..${seasons.length})');
    }
    final episodes =
        await _fetchEpisodesCached(_seasonUrl(animeUrl, season, vf));
    if (episodes.isEmpty) throw const ResolveException('aucun episode trouve');
    // Épisodes triés numériquement quand possible (comme le Python).
    final keys = episodes.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? (1 << 30);
        final bi = int.tryParse(b) ?? (1 << 30);
        return ai.compareTo(bi);
      });
    return [for (final k in keys) int.tryParse(k)].whereType<int>().toList();
  }

  /// Retourne la liste des hébergeurs alternatifs disponibles pour cet épisode.
  Future<List<VideoHosterSource>> listHosterSources({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final vf = _isVf(language);
    final (animeUrl, seasons) = await _seasonsFor(title);
    final s = _pickByIndex(seasons, season);
    if (s == null) {
      throw ResolveException(
          'saison #$season hors bornes (1..${seasons.length})');
    }
    final seasonUrl = _seasonUrl(animeUrl, s, vf);
    final seasonInfo = await _fetchSeasonInfoCached(seasonUrl);
    final episodes = seasonInfo.episodes;
    if (episodes.isEmpty) throw const ResolveException('aucun episode trouve');
    final ids = episodes['$episode'];
    if (ids == null || ids.isEmpty) return const [];

    final domain = await _ensureDomain();
    final validIds = ids.where((u) => urlHasId(u)).toList();
    final resolved = await Future.wait(validIds.map((link) async {
      final realUrl = await _resolveLien(
        domain,
        link,
        seasonInfo.jeton,
        seasonUrl,
      );
      String? name;
      if (link.startsWith('lien:')) {
        final id = link.substring(5).trim();
        final hostDomain = seasonInfo.meta[id]?.toLowerCase();
        if (hostDomain != null) {
          name = seasonInfo.lecteurNames[hostDomain] ??
              identifyHosterName(hostDomain);
        }
      }
      name ??= identifyHosterName(realUrl);
      return (name: name, url: realUrl);
    }));

    final totals = <String, int>{};
    for (final item in resolved) {
      totals[item.name] = (totals[item.name] ?? 0) + 1;
    }
    final indices = <String, int>{};
    final result = <VideoHosterSource>[];
    for (final item in resolved) {
      final idx = (indices[item.name] ?? 0) + 1;
      indices[item.name] = idx;
      final displayName =
          (totals[item.name] ?? 0) > 1 ? '${item.name} $idx' : item.name;
      result.add(VideoHosterSource(name: displayName, embedUrl: item.url));
    }
    return result;
  }

  /// Résout le flux direct d'un lecteur spécifique avec ses en-têtes HTTP requis.
  Future<VideoHosterSource?> resolveSource(VideoHosterSource source) async {
    final domain = await _ensureDomain();
    var s = source;
    if (s.embedUrl.startsWith('lien:')) {
      final resolvedUrl = _resolvedLiens[s.embedUrl];
      if (resolvedUrl != null) {
        s = s.copyWith(embedUrl: resolvedUrl);
      }
    }
    return resolveHosterSource(fetch, domain, s);
  }

  /// Résout la meilleure source vidéo disponible (ou [preferredSource] si demandée),
  /// avec son flux direct et ses en-têtes HTTP associés (Referer, User-Agent).
  Future<VideoHosterSource> resolveStreamSource({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
    VideoHosterSource? preferredSource,
  }) async {
    final sources = await listHosterSources(
      title: title,
      episode: episode,
      season: season,
      language: language,
    );
    if (sources.isEmpty) {
      throw const ResolveException('aucun lecteur disponible');
    }

    if (preferredSource != null) {
      final match = sources.firstWhere(
        (s) =>
            s.embedUrl == preferredSource.embedUrl ||
            s.name == preferredSource.name,
        orElse: () => preferredSource,
      );
      final resolved = await resolveSource(match);
      if (resolved != null && resolved.isResolved) return resolved;
    }

    for (final src in sources) {
      final resolved = await resolveSource(src);
      if (resolved != null && resolved.isResolved) {
        return resolved;
      }
    }

    // Fallback de dernier recours : resolveVideoUrl
    final domain = await _ensureDomain();
    final fallbackUrl = await resolveVideoUrl(
      fetch,
      domain,
      sources.map((s) => s.embedUrl).toList(),
    );
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return VideoHosterSource(
        name: 'Lecteur',
        embedUrl: fallbackUrl,
        directStreamUrl: fallbackUrl,
      );
    }

    throw const ResolveException('aucune URL de flux resolue');
  }

  @override
  Future<String> resolveStreamUrl({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final source = await resolveStreamSource(
      title: title,
      episode: episode,
      season: season,
      language: language,
    );
    return source.directStreamUrl!;
  }

  Future<SkipTimes> skipTimes({
    required String title,
    required int episode,
    int seasonIndex = 1,
    int? malId,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    try {
      final saison = seasonIndex > 1 ? 'Saison $seasonIndex' : null;
      final effectiveMalId = malId ?? _malIdByTitle[normText(title)];
      return await resolveSkipTimes(
        fetch,
        animeName: title,
        episode: episode,
        saison: saison,
        malId: effectiveMalId,
      );
    } catch (_) {
      return const SkipTimes();
    }
  }

  Future<List<AnimeSamaCatalogueItem>> search({
    required String query,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final domain = await _ensureDomain();
    final entries = await fetchCatalogue(fetch, domain, query, vf: _isVf(language));
    return [
      for (final e in entries)
        AnimeSamaCatalogueItem(
            title: e.title, url: e.url, slug: slugFromUrl(e.url))
    ];
  }

  Future<List<AnimeSamaPlanningItem>> planning({
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final domain = await _ensureDomain();
    final resp = await fetch('https://$domain/planning/', headers: kHeadersBase);
    if (!resp.ok) throw const ResolveException('planning indisponible');
    final items = parsePlanning(
      resp.body,
      vf: _isVf(language),
      formatTime: _formatReleaseTime,
    );
    return [
      for (final it in items)
        AnimeSamaPlanningItem(
          day: it.day,
          time: it.time,
          title: it.title,
          url: it.url,
          slug: it.slug,
        )
    ];
  }

  Future<AnimeSamaDetail?> catalogueDetail({required String slug}) async {
    final domain = await _ensureDomain();
    final s = slug.trim();
    if (s.isEmpty) return null;
    try {
      final resp =
          await fetch('https://$domain/catalogue/$s/', headers: kHeadersBase);
      final d = parseCatalogueDetail(resp.ok ? resp.body : '', s);
      if (d.malId != null) {
        _malIdBySlug[s] = d.malId!;
        _malIdByTitle[normText(d.title)] = d.malId!;
      }
      return AnimeSamaDetail(
        slug: s,
        title: d.title,
        alternativeTitles: d.alternativeTitles,
        synopsis: d.synopsis,
        genres: d.genres,
        cover: d.posterUrl ?? cdnImageUrl(s),
        banner: d.bannerUrl ?? cdnImageUrl(s, banner: true),
        score: d.score,
        anilistId: d.anilistId,
        malId: d.malId,
        tmdbId: d.tmdbId,
        korboUrl: d.korboUrl,
        trailerYoutubeId: d.trailerYoutubeId,
        format: d.format,
        status: d.status,
        releaseDate: d.releaseDate,
        seasonPeriod: d.seasonPeriod,
        totalEpisodes: d.totalEpisodes,
        studio: d.studio,
        broadcastChannels: d.broadcastChannels,
        authors: d.authors,
        nextEpisodeNumber: d.nextEpisodeNumber,
        nextEpisodeTimestamp: d.nextEpisodeTimestamp,
        nextEpisodeDateText: d.nextEpisodeDateText,
        similarAnime: [
          for (final it in d.similarAnime)
            AnimeSamaCatalogueItem(
              title: it.title,
              url: it.url,
              slug: it.slug,
              cover: it.coverUrl,
            )
        ],
      );
    } catch (_) {
      return AnimeSamaDetail(slug: s, title: s, cover: cdnImageUrl(s));
    }
  }

  Future<AnimeSamaHome> home() async {
    final domain = await _ensureDomain();
    final classics = [
      for (final slug in classicSlugs)
        AnimeSamaCatalogueItem(
          title: slug.replaceAll('-', ' '),
          url: 'https://$domain/catalogue/$slug/',
          slug: slug,
          cover: cdnImageUrl(slug),
        )
    ];
    var latest = <AnimeSamaCatalogueItem>[];
    try {
      final resp = await fetch(catalogueUrl(domain), headers: kHeadersBase);
      if (resp.ok) latest = _cardsToItems(parseCards(resp.body, domain));
    } catch (_) {
      // best-effort
    }
    return AnimeSamaHome(classics: classics, latestEpisodes: latest);
  }

  Future<List<AnimeSamaCatalogueItem>> catalogueByGenre({
    required String genre,
  }) async {
    return catalogueFilter(genre: genre);
  }

  Future<List<AnimeSamaCatalogueItem>> catalogueFilter({
    String genre = '',
    String anneeMin = '',
    String anneeMax = '',
    String episodesMin = '',
    String episodesMax = '',
  }) async {
    final domain = await _ensureDomain();
    const target = 100;
    const hardMaxPages = 60;
    final items = <CatalogueCard>[];
    final seen = <String>{};
    var lastPage = hardMaxPages;
    var page = 1;
    while (page <= lastPage) {
      final url = catalogueUrl(
        domain,
        genre: genre.trim(),
        page: page,
        anneeMin: anneeMin.trim(),
        anneeMax: anneeMax.trim(),
        episodesMin: episodesMin.trim(),
        episodesMax: episodesMax.trim(),
      );
      final HttpResponse resp;
      try {
        resp = await fetch(url, headers: kHeadersBase);
      } catch (_) {
        break;
      }
      if (!resp.ok) break;
      if (page == 1) {
        final lp = catalogueLastPage(resp.body);
        lastPage = lp < hardMaxPages ? lp : hardMaxPages;
      }
      final cards = parseCards(resp.body, domain);
      var fresh = 0;
      for (final c in cards) {
        if (seen.contains(c.slug)) continue;
        seen.add(c.slug);
        fresh++;
        items.add(c);
      }
      if (fresh == 0 || items.length >= target) break;
      page++;
    }
    return _cardsToItems(items);
  }

  List<AnimeSamaCatalogueItem> _cardsToItems(List<CatalogueCard> cards) => [
        for (final c in cards)
          AnimeSamaCatalogueItem(
            title: c.title,
            url: c.url,
            slug: c.slug,
            cover: c.coverUrl,
            genres: c.genres,
          )
      ];
}
