/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Actions catalogue anime-sama : détail d'une fiche, cartes de catalogue,
/// planning hebdomadaire, sections d'accueil. Port fidèle des fonctions
/// homonymes d'`animesama_resolve.py` (action_catalogue_detail, _cards_from_html,
/// action_planning, action_home, _normalize_genres, _cdn_image_url, _slug_from_url).
library;

/// Extensions CDN testées dans l'ordre (cover=webp d'abord, bannière=jpg).
const _cdnCoverExts = ['webp', 'jpg', 'png'];
const _cdnBannerExts = ['jpg', 'webp', 'png'];

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

/// Détail scrapé d'une fiche : titre, synopsis, genres.
class CatalogueDetailData {
  final String slug;
  final String title;
  final String? synopsis;
  final List<String> genres;
  const CatalogueDetailData({
    required this.slug,
    required this.title,
    this.synopsis,
    this.genres = const [],
  });
}

/// Parse le HTML d'une fiche `/catalogue/<slug>/`. Port EXACT de
/// `action_catalogue_detail` (partie parsing : h1, #synopsisText, genres).
CatalogueDetailData parseCatalogueDetail(String htmlContent, String slug) {
  var title = slug;
  String? synopsis;
  var genres = <String>[];

  final mt = RegExp(r'<h1[^>]*>([^<]+)</h1>').firstMatch(htmlContent);
  if (mt != null) title = mt.group(1)!.trim();

  final ms = RegExp(r'<p[^>]+id="synopsisText"[^>]*>(.*?)</p>',
          dotAll: true, caseSensitive: false)
      .firstMatch(htmlContent);
  if (ms != null) {
    synopsis = ms.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  final mw = RegExp(r'<div[^>]+class="[^"]*genres-wrap[^"]*"[^>]*>(.*?)</div>',
          dotAll: true, caseSensitive: false)
      .firstMatch(htmlContent);
  if (mw != null) {
    final pills = RegExp(
            r'<span[^>]+class="[^"]*genre-pill[^"]*"[^>]*>([^<]+)</span>',
            caseSensitive: false)
        .allMatches(mw.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
    genres = normalizeGenres(pills);
  }

  return CatalogueDetailData(
      slug: slug, title: title, synopsis: synopsis, genres: genres);
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

/// Type de contenu d'une carte (« Anime », « Scans »…). Port de `_card_type`.
String _cardType(String inner) {
  final m = RegExp(
          r'type-row"?\s*>.*?<p[^>]+class="[^"]*info-value[^"]*"[^>]*>([^<]+)</p>',
          dotAll: true, caseSensitive: false)
      .firstMatch(inner);
  return m?.group(1)?.trim() ?? '';
}

/// Vrai si la carte contient de la vidéo (anime/film), pas du pur « Scans ».
/// Port EXACT de `_is_video_card` (garde par défaut si type absent).
bool _isVideoCard(String inner) {
  final t = _cardType(inner).toLowerCase();
  if (t.isEmpty) return true;
  return t.contains('anime') || t.contains('film');
}

/// Parse les cartes d'un fragment de catalogue. Port EXACT de `_cards_from_html`.
List<CatalogueCard> parseCards(String htmlContent, String domain) {
  final cardRe = RegExp(
    r'<a\s[^>]*href="https?://[^"]*?/catalogue/([^/"]+)/?[^"]*"[^>]*>(.*?)</a>',
    dotAll: true,
  );
  final imgRe = RegExp(
      r'<img[^>]+class="[^"]*card-image[^"]*"[^>]+src="([^"]+)"',
      dotAll: true);
  final imgAltRe = RegExp(r'<img[^>]+src="([^"]+)"', dotAll: true);
  final titleRe = RegExp(r'<h2[^>]*card-title[^>]*>([^<]+)</h2>', dotAll: true);
  final genreTagRe = RegExp(
      r'<span[^>]+class="[^"]*genre-tag[^"]*"[^>]*>([^<]+)</span>',
      caseSensitive: false);

  final items = <CatalogueCard>[];
  for (final m in cardRe.allMatches(htmlContent)) {
    final slug = m.group(1)!.trim();
    final inner = m.group(2)!;
    if (!_isVideoCard(inner)) continue;
    final mt = titleRe.firstMatch(inner);
    if (mt == null) continue;
    final title = mt.group(1)!.trim();
    final mc = imgRe.firstMatch(inner) ?? imgAltRe.firstMatch(inner);
    final coverUrl = mc != null ? mc.group(1)!.trim() : cdnImageUrl(slug);
    final genres = normalizeGenres(
        genreTagRe.allMatches(inner).map((g) => g.group(1)!).toList());
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
  final dayPattern = RegExp(r'<h2 class="titreJours[^>]*>([^<]+)</h2>');
  final planning = {
    for (final m in dayPattern.allMatches(htmlContent))
      m.group(1)!.trim(): <PlanningItemData>[]
  };
  // Reproduit Python `re.split` AVEC groupe capturant : le résultat alterne
  // [texte, capture, texte, capture, ...]. Dart `String.split` ne conserve PAS
  // les captures, on reconstruit donc la liste à la main.
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
