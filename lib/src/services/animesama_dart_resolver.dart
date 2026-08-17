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

  DartAnimeSamaResolver({required this.fetch});

  /// Résout (une fois) puis renvoie le domaine anime-sama courant.
  Future<String> _ensureDomain() async {
    return _domain ??= await resolveCurrentDomain(fetch);
  }

  bool _isVf(PlaybackLanguage language) => language == PlaybackLanguage.vf;

  // --- Saisons réelles (port de _seasons_for) --------------------------------

  /// Retourne (anime_url, saisons réelles) ou lève [ResolveException].
  /// Applique le filtrage complet : vraies saisons + dédup + arrêt anticipé.
  Future<(String, List<RawSeason>)> _seasonsFor(
    String title,
    bool vf,
  ) async {
    final domain = await _ensureDomain();
    final found = await searchCatalogue(fetch, domain, title, vf: vf);
    if (found == null) {
      throw ResolveException('aucun anime correspondant a "$title"');
    }
    final animeUrl = found.url;
    final resp = await fetch(animeUrl, headers: kHeadersBase);
    final raw = parseSeasons(resp.body);
    final candidates = dedupeSeasons(raw.where(isRealSeason).toList());

    final real = <RawSeason>[];
    for (final s in candidates) {
      if (await _seasonHasEpisodes(animeUrl, s, vf)) {
        real.add(s);
      } else if (real.isNotEmpty) {
        break; // saisons factices contiguës en fin de liste -> arrêt anticipé
      }
    }
    if (real.isEmpty) {
      throw const ResolveException('aucune saison avec episodes trouvee');
    }
    return (animeUrl, real);
  }

  /// URL complète d'une saison (concatène anime_url + chemin, réécrit VF).
  String _seasonUrl(String animeUrl, RawSeason s, bool vf) {
    var url = '${animeUrl.replaceAll(RegExp(r'/+$'), '')}/'
        '${s.url.replaceAll(RegExp(r'^/+'), '')}';
    if (vf) url = url.replaceAll('vostfr', 'vf');
    return url;
  }

  /// Vrai si la saison a au moins un épisode réellement jouable.
  /// Port de `_season_has_episodes`.
  Future<bool> _seasonHasEpisodes(
      String animeUrl, RawSeason s, bool vf) async {
    try {
      final eps = await fetchEpisodes(fetch, _seasonUrl(animeUrl, s, vf));
      return playableEpisodeCount(eps) > 0;
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
    final (_, seasons) = await _seasonsFor(title, _isVf(language));
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
    final (animeUrl, seasons) = await _seasonsFor(title, vf);
    final season = _pickByIndex(seasons, seasonIndex);
    if (season == null) {
      throw ResolveException(
          'saison #$seasonIndex hors bornes (1..${seasons.length})');
    }
    final episodes = await fetchEpisodes(fetch, _seasonUrl(animeUrl, season, vf));
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

  @override
  Future<String> resolveStreamUrl({
    required String title,
    required int episode,
    int season = 1,
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final vf = _isVf(language);
    final domain = await _ensureDomain();
    final (animeUrl, seasons) = await _seasonsFor(title, vf);
    final s = _pickByIndex(seasons, season);
    if (s == null) {
      throw ResolveException(
          'saison #$season hors bornes (1..${seasons.length})');
    }
    final episodes = await fetchEpisodes(fetch, _seasonUrl(animeUrl, s, vf));
    if (episodes.isEmpty) throw const ResolveException('aucun episode trouve');
    final ids = episodes['$episode'];
    if (ids == null) {
      throw ResolveException('episode $episode indisponible');
    }
    final url = await resolveVideoUrl(fetch, domain, ids);
    if (url == null || url.isEmpty) {
      throw const ResolveException('aucune URL de flux resolue');
    }
    return url;
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
      return await resolveSkipTimes(
        fetch,
        animeName: title,
        episode: episode,
        saison: saison,
        malId: malId,
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
      return AnimeSamaDetail(
        slug: s,
        title: d.title,
        synopsis: d.synopsis,
        genres: d.genres,
        cover: cdnImageUrl(s),
        banner: cdnImageUrl(s, banner: true),
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
