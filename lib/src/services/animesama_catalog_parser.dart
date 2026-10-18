/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Actions catalogue anime-sama : détail d'une fiche, cartes de catalogue,
/// planning hebdomadaire, sections d'accueil. Port fidèle des fonctions
/// homonymes d'`animesama_resolve.py` (action_catalogue_detail, _cards_from_html,
/// action_planning, action_home, _normalize_genres, _cdn_image_url, _slug_from_url).
library;

import 'package:html/parser.dart' as html_parser;

/// Extensions CDN testées dans l'ordre (cover=webp d'abord, bannière=jpg).
const _cdnCoverExts = ['webp', 'jpg', 'png'];
const _cdnBannerExts = ['jpg', 'webp', 'png'];

/// Retire les accents français basiques pour normaliser les clés/balises.
String _stripAccents(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ûüù]'), 'u')
    .replaceAll(RegExp(r'[ç]'), 'c');

/// Normalise un texte pour matching (minuscule alphanumérique). Port de `_norm`.
String normText(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Extrait le slug d'une URL `/catalogue/<slug>/`. Port de `_slug_from_url`.
String slugFromUrl(String? url) {
  final m = RegExp(r'/catalogue/([^/]+)').firstMatch(url ?? '');
  return m?.group(1)?.trim() ?? '';
}

/// URL CDN d'une image dérivée du slug (probe=false : 1re extension directe).
/// Port de `_cdn_image_url` sans les requêtes HEAD (le widget Dart re-teste).
String cdnImageUrl(String slug, {bool banner = false}) {
  final sub = banner ? '' : 'thumb/';
  final exts = banner ? _cdnBannerExts : _cdnCoverExts;
  return 'https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/$sub$slug.${exts[0]}';
}

/// Décode les entités HTML de base (le Python utilise `html.unescape`).
String unescapeHtml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&nbsp;', ' ');

/// Nettoie/normalise une liste de genres scrapés. Port EXACT de
/// `_normalize_genres` : décode entités, recolle « Science-Fiction », dédup.
List<String> normalizeGenres(List<String> raw) {
  final cleaned = <String>[];
  for (var g in raw) {
    g = unescapeHtml(g);
    g = g.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (g.isNotEmpty && g.length > 1) cleaned.add(g);
  }
  final merged = <String>[];
  var i = 0;
  while (i < cleaned.length) {
    final cur = cleaned[i];
    final nxt = i + 1 < cleaned.length ? cleaned[i + 1] : null;
    if (cur.toLowerCase() == 'science' &&
        nxt != null &&
        nxt.toLowerCase() == 'fiction') {
      merged.add('Science-Fiction');
      i += 2;
      continue;
    }
    if (cur.toLowerCase() == 'fiction') {
      i += 1;
      continue;
    }
    merged.add(cur);
    i += 1;
  }
  final seen = <String>{};
  final out = <String>[];
  for (final g in merged) {
    final k = g.toLowerCase();
    if (!seen.contains(k)) {
      seen.add(k);
      out.add(g);
    }
  }
  return out;
}

/// Détail scrapé d'une fiche : titre, synopsis, genres et métadonnées enrichies (refonte Anime-Sama).
class CatalogueDetailData {
  final String slug;
  final String title;
  final String? alternativeTitles;
  final String? synopsis;
  final List<String> genres;
  final String? posterUrl;
  final String? bannerUrl;
  final double? score;
  final int? anilistId;
  final int? malId;
  final int? tmdbId;
  final String? korboUrl;
  final String? trailerYoutubeId;
  final String? format;
  final String? status;
  final String? releaseDate;
  final String? seasonPeriod;
  final int? totalEpisodes;
  final String? studio;
  final String? broadcastChannels;
  final String? authors;
  final int? nextEpisodeNumber;
  final int? nextEpisodeTimestamp;
  final String? nextEpisodeDateText;
  final List<CatalogueCard> similarAnime;

  const CatalogueDetailData({
    required this.slug,
    required this.title,
    this.alternativeTitles,
    this.synopsis,
    this.genres = const [],
    this.posterUrl,
    this.bannerUrl,
    this.score,
    this.anilistId,
    this.malId,
    this.tmdbId,
    this.korboUrl,
    this.trailerYoutubeId,
    this.format,
    this.status,
    this.releaseDate,
    this.seasonPeriod,
    this.totalEpisodes,
    this.studio,
    this.broadcastChannels,
    this.authors,
    this.nextEpisodeNumber,
    this.nextEpisodeTimestamp,
    this.nextEpisodeDateText,
    this.similarAnime = const [],
  });
}

/// Parse le HTML d'une fiche `/catalogue/<slug>/`. Supporte à la fois
/// le nouveau design Anime-Sama (.oe-*) et l'ancien design (h1, #synopsisText).
CatalogueDetailData parseCatalogueDetail(String htmlContent, String slug) {
  var title = slug;
  String? synopsis;
  var genres = <String>[];

  final doc = html_parser.parse(htmlContent);

  // Titre principal
  final titleEl = doc.querySelector('#titreOeuvre, h1.oe-titre, h1');
  if (titleEl != null && titleEl.text.trim().isNotEmpty) {
    title = titleEl.text.trim();
  }

  // Titres alternatifs (#titreAlter)
  final alterEl = doc.querySelector('#titreAlter, .oe-alters');
  final alternativeTitles = (alterEl != null && alterEl.text.trim().isNotEmpty)
      ? alterEl.text.trim()
      : null;

  // Synopsis
  final synEl = doc.querySelector('#synopsisText, .oe-synopsis p, .synopsis');
  if (synEl != null && synEl.text.trim().isNotEmpty) {
    synopsis = synEl.text.trim();
  }

  // Genres
  final pills = doc
      .querySelectorAll('.oe-genres .genre-pill, .genres-wrap .genre-pill, .genre-pill')
      .map((e) => e.text.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (pills.isNotEmpty) {
    genres = normalizeGenres(pills);
  }

  // Affiche / Cover HD (TMDB / CDN) & Bannière
  final posterEl = doc.querySelector('.oe-affiche img');
  final posterUrl = posterEl?.attributes['src']?.trim();

  final bannerEl = doc.querySelector('.oe-fond img');
  final bannerUrl = bannerEl?.attributes['src']?.trim();

  // Note / Score (ex: 6,8 / 10 sur AniList)
  double? score;
  final scoreEl = doc.querySelector('.oe-notes .oe-note b, .oe-note b');
  if (scoreEl != null) {
    final clean = scoreEl.text.trim().replaceAll(',', '.');
    score = double.tryParse(clean);
  }

  // Liens externes (AniList, MyAnimeList, TMDB, Korbo)
  int? anilistId;
  int? malId;
  int? tmdbId;
  String? korboUrl;

  for (final a in doc.querySelectorAll('a[href]')) {
    final href = a.attributes['href'] ?? '';
    if (anilistId == null && href.contains('anilist.co/anime/')) {
      final m = RegExp(r'anilist\.co/anime/(\d+)').firstMatch(href);
      if (m != null) anilistId = int.tryParse(m.group(1)!);
    }
    if (malId == null && href.contains('myanimelist.net/anime/')) {
      final m = RegExp(r'myanimelist\.net/anime/(\d+)').firstMatch(href);
      if (m != null) malId = int.tryParse(m.group(1)!);
    }
    if (tmdbId == null && href.contains('themoviedb.org/')) {
      final m = RegExp(r'themoviedb\.org/(?:tv|movie)/(\d+)').firstMatch(href);
      if (m != null) tmdbId = int.tryParse(m.group(1)!);
    }
    if (korboUrl == null && href.contains('korbo.fr/oeuvre/')) {
      korboUrl = href.trim();
    }
  }

  // Bande-annonce YouTube
  final ytBtn = doc.querySelector('button[data-youtube], .btn-ba[data-youtube]');
  final trailerYoutubeId = ytBtn?.attributes['data-youtube']?.trim();

  // Liste de métadonnées (dl.oe-infos)
  final infoMap = <String, String>{};
  final dl = doc.querySelector('dl.oe-infos');
  if (dl != null) {
    final dts = dl.querySelectorAll('dt');
    final dds = dl.querySelectorAll('dd');
    final count = dts.length < dds.length ? dts.length : dds.length;
    for (var i = 0; i < count; i++) {
      final key = normText(_stripAccents(dts[i].text));
      infoMap[key] = dds[i].text.trim();
    }
  }

  final format = infoMap['format'];
  final status = infoMap['statut'];
  final releaseDate = infoMap['diffusion'];
  final seasonPeriod = infoMap['saison'];
  final epStr = infoMap['episodes'];
  final totalEpisodes = epStr != null ? int.tryParse(epStr) : null;
  final studio = infoMap['studio'];
  final broadcastChannels = infoMap['chaine'];
  final authors = infoMap['createur'];

  // Prochain épisode (.oe-prochain)
  int? nextEpisodeTimestamp;
  int? nextEpisodeNumber;
  String? nextEpisodeDateText;

  final prochainEl = doc.querySelector('.oe-prochain');
  if (prochainEl != null) {
    final tsStr = prochainEl.attributes['data-heure']?.trim();
    if (tsStr != null) nextEpisodeTimestamp = int.tryParse(tsStr);

    final titreEl = prochainEl.querySelector('.oe-prochain-titre');
    if (titreEl != null) {
      final m = RegExp(r'(\d+)').firstMatch(titreEl.text);
      if (m != null) nextEpisodeNumber = int.tryParse(m.group(1)!);
    }

    final dateEl = prochainEl.querySelector('.oe-prochain-date');
    if (dateEl != null) {
      nextEpisodeDateText = dateEl.text.trim();
    }
  }

  // Œuvres similaires (#containerSimilaires)
  final similarAnime = <CatalogueCard>[];
  for (final card in doc.querySelectorAll(
      '#containerSimilaires .as-carte, #containerSimilaires .as-carte-oeuvre')) {
    final nom = (card.attributes['data-nom'] ?? '').trim().isNotEmpty
        ? card.attributes['data-nom']!.trim()
        : (card.querySelector('.as-carte-titre, h3')?.text.trim() ?? '');
    final a = card.querySelector('a[href]');
    final href = card.attributes['data-url'] ?? a?.attributes['href'] ?? '';
    final cardSlug = slugFromUrl(href);
    if (nom.isEmpty || cardSlug.isEmpty) continue;
    final img = card.attributes['data-img'] ??
        card.querySelector('img')?.attributes['src'] ??
        cdnImageUrl(cardSlug);
    final fullUrl = href.startsWith('http')
        ? href
        : 'https://anime-sama.to${href.startsWith('/') ? href : '/$href'}';
    similarAnime.add(CatalogueCard(
      title: nom,
      url: fullUrl,
      slug: cardSlug,
      coverUrl: img,
    ));
  }

  return CatalogueDetailData(
    slug: slug,
    title: title,
    alternativeTitles: alternativeTitles,
    synopsis: synopsis,
    genres: genres,
    posterUrl: posterUrl,
    bannerUrl: bannerUrl,
    score: score,
    anilistId: anilistId,
    malId: malId,
    tmdbId: tmdbId,
    korboUrl: korboUrl,
    trailerYoutubeId: trailerYoutubeId,
    format: format,
    status: status,
    releaseDate: releaseDate,
    seasonPeriod: seasonPeriod,
    totalEpisodes: totalEpisodes,
    studio: studio,
    broadcastChannels: broadcastChannels,
    authors: authors,
    nextEpisodeNumber: nextEpisodeNumber,
    nextEpisodeTimestamp: nextEpisodeTimestamp,
    nextEpisodeDateText: nextEpisodeDateText,
    similarAnime: similarAnime,
  );
}

/// Une carte de catalogue (titre + slug + genres + cover).
class CatalogueCard {
  final String title;
  final String url;
  final String slug;
  final String coverUrl;
  final List<String> genres;
  const CatalogueCard({
    required this.title,
    required this.url,
    required this.slug,
    required this.coverUrl,
    this.genres = const [],
  });
}


/// Parse les cartes d'un fragment de catalogue. Port de `_cards_from_html`.
/// Supporte la refonte Anime-Sama (.as-carte / .as-carte-oeuvre) et l'ancien format.
List<CatalogueCard> parseCards(String htmlContent, String domain) {
  final doc = html_parser.parse(htmlContent);
  final items = <CatalogueCard>[];

  // 1) Refonte Anime-Sama : cartes structurées .as-carte / .as-carte-oeuvre
  final asCards = doc.querySelectorAll('.as-carte, .as-carte-oeuvre');
  if (asCards.isNotEmpty) {
    final seenSlugs = <String>{};
    for (final card in asCards) {
      final aTag = card.querySelector('a[href]');
      final href = card.attributes['data-url'] ?? aTag?.attributes['href'] ?? '';
      final slug = slugFromUrl(href);
      if (slug.isEmpty || slug == 'catalogue' || seenSlugs.contains(slug)) continue;

      // Filtre les scans purs s'il y a un badge Scan et pas de badge Anime
      final badges = card
          .querySelectorAll('.as-badge')
          .map((b) => b.text.trim().toLowerCase())
          .toList();
      if (badges.isNotEmpty &&
          badges.contains('scans') &&
          !badges.contains('anime')) {
        continue;
      }

      final title = (card.attributes['data-nom'] ?? '').trim().isNotEmpty
          ? card.attributes['data-nom']!.trim()
          : (card.querySelector('.as-carte-titre, h3, h2, .card-title')?.text.trim() ?? '');
      if (title.isEmpty) continue;

      seenSlugs.add(slug);

      final imgEl = card.querySelector('img');
      final coverSrc = card.attributes['data-img']?.trim() ??
          imgEl?.attributes['src']?.trim();
      final coverUrl = (coverSrc != null && coverSrc.isNotEmpty)
          ? coverSrc
          : cdnImageUrl(slug);

      final fullUrl = href.startsWith('http')
          ? href
          : 'https://$domain${href.startsWith('/') ? href : '/$href'}';

      items.add(CatalogueCard(
        title: title,
        url: fullUrl,
        slug: slug,
        coverUrl: coverUrl,
        genres: const [],
      ));
    }
    if (items.isNotEmpty) return items;
  }

  // 2) Rétro-compatibilité : ancien format avec a[href*="/catalogue/"]
  for (final card in doc.querySelectorAll('a[href*="/catalogue/"]')) {
    final href = card.attributes['href'] ?? '';
    final slugMatch = RegExp(r'/catalogue/([^/"]+)').firstMatch(href);
    if (slugMatch == null) continue;
    final slug = slugMatch.group(1)!.trim();
    if (slug.isEmpty || slug == 'catalogue') continue;

    // Doit être une carte vidéo (anime/film), pas du pur Scans
    final typeEl =
        card.querySelector('.info-value') ?? card.querySelector('.type-row');
    final typeText = typeEl?.text.trim().toLowerCase() ?? '';
    if (typeText.isNotEmpty &&
        !typeText.contains('anime') &&
        !typeText.contains('film')) {
      continue;
    }

    final titleEl =
        card.querySelector('.card-title') ?? card.querySelector('h2');
    if (titleEl == null || titleEl.innerHtml.trim().isEmpty) continue;
    final title = titleEl.innerHtml.trim();

    final imgEl =
        card.querySelector('img.card-image') ?? card.querySelector('img');
    final coverSrc = imgEl?.attributes['src']?.trim();
    final coverUrl = (coverSrc != null && coverSrc.isNotEmpty)
        ? coverSrc
        : cdnImageUrl(slug);

    final genreEls = card.querySelectorAll('.genre-tag');
    final genres = normalizeGenres(
        genreEls.map((g) => g.text.trim()).where((g) => g.isNotEmpty).toList());

    items.add(CatalogueCard(
      title: title,
      url: 'https://$domain/catalogue/$slug/',
      slug: slug,
      coverUrl: coverUrl,
      genres: genres,
    ));
  }
  return items;
}

/// Une entrée du planning : jour + heure + titre + url + slug.
class PlanningItemData {
  final String day;
  final String time;
  final String title;
  final String url;
  final String slug;
  const PlanningItemData({
    required this.day,
    required this.time,
    required this.title,
    required this.url,
    required this.slug,
  });
}

/// Vrai si l'URL est une page de scans (manga). Port de `_is_scan_url`.
bool isScanUrl(String url) {
  final parts = url.trim().split('/').where((p) => p.isNotEmpty).toList();
  return parts.length >= 3 && parts[2].toLowerCase().startsWith('scan');
}

/// Parse le planning hebdomadaire pour une langue. Port EXACT de
/// `action_planning` (hors formatage d'heure, qui dépend du fuseau — voir note).
///
/// [formatTime] convertit un timestamp Unix en « HHhMM » (injecté pour rester
/// pur/testable ; en prod, basé sur l'heure locale comme le Python).
List<PlanningItemData> parsePlanning(
  String htmlContent, {
  bool vf = false,
  required String Function(int ts) formatTime,
}) {
  final doc = html_parser.parse(htmlContent);
  final dayHeaders = doc.querySelectorAll('h2.titreJours');
  if (dayHeaders.isNotEmpty) {
    final items = <PlanningItemData>[];
    final seen = <String>{};
    for (final dayHeader in dayHeaders) {
      final currentDay = dayHeader.text.trim();
      final dayContainer = dayHeader.parent ?? dayHeader;
      for (final card in dayContainer.querySelectorAll('.planning-card')) {
        final classAttr = card.attributes['class'] ?? '';
        if (classAttr.contains('scan-card-premium') ||
            classAttr.split(RegExp(r'\s+')).contains('Scans')) {
          continue;
        }
        final aTag = card.querySelector('a[href]');
        final cardUrl = aTag?.attributes['href']?.trim() ?? '';
        if (cardUrl.isEmpty || isScanUrl(cardUrl)) continue;

        final titleAttr = card.attributes['data-title'];
        final title = (titleAttr != null && titleAttr.isNotEmpty)
            ? unescapeHtml(titleAttr).trim()
            : (card.querySelector('.card-title')?.text.trim() ?? '');

        final isVf = classAttr.split(RegExp(r'\s+')).contains('VF') ||
            cardUrl.toLowerCase().contains('/vf/');
        final isVo = classAttr.split(RegExp(r'\s+')).contains('VOSTFR') ||
            cardUrl.toLowerCase().contains('/vostfr/');
        if (vf && !isVf) continue;
        if (!vf && isVf && !isVo) continue;

        final slug = slugFromUrl(cardUrl);
        final key = '$currentDay|$slug';
        if (slug.isEmpty || seen.contains(key)) continue;
        seen.add(key);

        final tsAttr = card.attributes['data-release-ts'];
        final ts = tsAttr != null ? int.tryParse(tsAttr) : null;
        final time = ts != null ? formatTime(ts) : '?';

        items.add(PlanningItemData(
          day: currentDay,
          time: time,
          title: title,
          url: cardUrl,
          slug: slug,
        ));
      }
    }
    return items;
  }

  // Fallback regex si pas de hiérarchie de conteneurs standard
  final dayPattern = RegExp(r'<h2 class="titreJours[^>]*>([^<]+)</h2>');
  final planning = {
    for (final m in dayPattern.allMatches(htmlContent))
      m.group(1)!.trim(): <PlanningItemData>[]
  };
  final daySections = _splitKeepingGroup(htmlContent, dayPattern);

  final cardRe = RegExp(
    r'(<div[^>]*\bplanning-card\b[^>]*>)\s*<a href="(/catalogue/[^"]+)"',
    dotAll: true, caseSensitive: false,
  );
  final titleRe = RegExp(r'data-title="([^"]*)"');
  final tsRe = RegExp(r'data-release-ts="(\d+)"');

  final items = <PlanningItemData>[];
  final seen = <String>{};
  for (var i = 1; i < daySections.length; i += 2) {
    final currentDay = daySections[i].trim();
    final dayContent = daySections[i + 1];
    if (!planning.containsKey(currentDay)) continue;
    for (final m in cardRe.allMatches(dayContent)) {
      final divTag = m.group(1)!;
      final cardUrl = m.group(2)!.trim();
      if (divTag.contains('scan-card-premium') ||
          RegExp(r'\bScans\b').hasMatch(divTag)) {
        continue;
      }
      final mt = titleRe.firstMatch(divTag);
      final title = mt != null ? unescapeHtml(mt.group(1)!).trim() : '';
      final isVf = RegExp(r'\bVF\b').hasMatch(divTag) ||
          cardUrl.toLowerCase().contains('/vf/');
      final isVo = RegExp(r'\bVOSTFR\b').hasMatch(divTag) ||
          cardUrl.toLowerCase().contains('/vostfr/');
      if (vf && !isVf) continue;
      if (!vf && isVf && !isVo) continue;
      if (isScanUrl(cardUrl)) continue;
      final slug = slugFromUrl(cardUrl);
      final key = '$currentDay|$slug';
      if (slug.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      final mts = tsRe.firstMatch(divTag);
      final time = mts != null ? formatTime(int.parse(mts.group(1)!)) : '?';
      items.add(PlanningItemData(
        day: currentDay,
        time: time,
        title: title,
        url: cardUrl,
        slug: slug,
      ));
    }
  }
  return items;
}

/// Reproduit `re.split(pattern, s)` de Python quand [pattern] a UN groupe
/// capturant : le résultat alterne [texte_avant, groupe1, texte_après, ...].
/// (Dart `String.split(RegExp)` omet les captures — d'où ce helper.)
List<String> _splitKeepingGroup(String s, RegExp pattern) {
  final result = <String>[];
  var last = 0;
  for (final m in pattern.allMatches(s)) {
    result.add(s.substring(last, m.start));
    result.add(m.group(1) ?? '');
    last = m.end;
  }
  result.add(s.substring(last));
  return result;
}

/// Construit une URL de catalogue filtré (filtre serveur). Port de `_catalogue_url`.
String catalogueUrl(
  String domain, {
  String genre = '',
  int page = 1,
  String anneeMin = '',
  String anneeMax = '',
  String episodesMin = '',
  String episodesMax = '',
}) {
  String enc(String s) => Uri.encodeQueryComponent(s);
  var qs = 'type%5B%5D=Anime'
      '&annee_min=${enc(anneeMin)}&annee_max=${enc(anneeMax)}'
      '&episodes_min=${enc(episodesMin)}&episodes_max=${enc(episodesMax)}'
      '&chapitres_min=&chapitres_max='
      '&genre%5B%5D=${enc(genre)}&search=';
  if (page > 1) qs += '&page=$page';
  return 'https://$domain/catalogue/?$qs';
}

/// Numéro de la dernière page du catalogue (liens ?page=N). Port de
/// `_catalogue_last_page`.
int catalogueLastPage(String htmlContent) {
  final nums = RegExp(r'[?&]page=(\d+)')
      .allMatches(htmlContent)
      .map((m) => int.parse(m.group(1)!))
      .toList();
  return nums.isEmpty ? 1 : nums.reduce((a, b) => a > b ? a : b);
}

/// Slugs des animes « classiques » (sections home non scrapables).
/// Port EXACT de `_CLASSIC_SLUGS`.
const List<String> classicSlugs = [
  'one-piece', 'demon-slayer', 'slam-dunk', 'detective-conan', 'dragon-ball',
  'shingeki-no-kyojin', 'naruto', 'haikyuu', 'fullmetal-alchemist',
  'jojos-bizarre-adventure', 'hunter-x-hunter', 'gintama', 'kingdom',
  'world-trigger', 'my-hero-academia', 'yuyu-hakusho', 'jujutsu-kaisen',
  'ken-le-survivant', 'bleach', 'banana-fish', 'inuyasha', 'ashita-no-joe',
  'kenshin-le-vagabond', 'golden-kamui', 'tokyo-ghoul',
  'the-quintessential-quintuplets', 'the-promised-neverland', 'hajime-no-ippo',
  'master-keaton', 'kaguya-sama-love-is-war', 'assassination-classroom',
  'kuroko-no-basket', 'black-butler', 'candy-candy', 'city-hunter',
  'chainsaw-man', 'parasite', 'urusei-yatsura', 'card-captor-sakura',
  'bungou-stray-dogs', 'fairy-tail', 'katekyo-hitman-reborn', 'hana-yori-dango',
  'galaxy-express-999', 'devilman-crybaby', 'magi-the-labyrinth-of-magic',
  'hikaru-no-go', 'major', 'fire-force', 'toilet-bound-hanako-kun',
  'karakuri-circus', 'fruits-basket', 'berserk', 'rent-a-girlfriend',
  'd-gray-man', 'captain-tsubasa', 'march-comes-in-like-a-lion', 'dr-stone',
];
