/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Identité d'un anime **absent d'AniList**. anime-sama est la source de vérité :
/// quand un titre n'a pas de correspondance AniList, on lui fabrique un
/// identifiant technique **stable** dérivé de son titre normalisé.
///
/// L'identifiant est **négatif** pour ne jamais entrer en collision avec un vrai
/// `anilistId` (toujours positif). Il est déterministe : le même titre donne
/// toujours le même id, ce qui permet de retrouver la bibliothèque/progression.
///
/// Note : on dérive du **titre**, pas de l'URL anime-sama (qui change souvent).
library;

/// Normalise un titre pour l'identité (minuscule, alphanumérique uniquement).
String normalizeAnimeTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Identifiant technique stable et **négatif** pour un anime anime-sama absent
/// d'AniList, dérivé de son [title].
///
/// - Déterministe : même titre → même id.
/// - Toujours < 0 (jamais 0), donc jamais en collision avec un `anilistId` réel.
int animeSamaIdFor(String title) {
  final norm = normalizeAnimeTitle(title);
  // FNV-1a 32 bits : hash déterministe, indépendant de la plateforme.
  var hash = 0x811c9dc5;
  for (final unit in norm.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // Réduit à un positif non nul, puis rend négatif.
  final positive = (hash & 0x7fffffff);
  final nonZero = positive == 0 ? 1 : positive;
  return -nonZero;
}

/// Mots vides ignorés pour la comparaison de titres (ils gonflent le
/// dénominateur et font échouer les titres longs sans vraie divergence).
const _titleStopwords = {
  'the', 'a', 'an', 'of', 'to', 'in', 'and', 'le', 'la', 'les', 'un', 'une',
  'de', 'des', 'du', 'et', 'no', 'wa', 'ga', 'season', 'saison', 'part',
  'decided', 'take',
};

/// Découpe un titre en jetons significatifs (>= 2 lettres, hors mots vides).
Set<String> _titleTokens(String title) => title
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.length >= 2 && !_titleStopwords.contains(t))
    .toSet();

/// Décide si deux titres désignent probablement le même anime.
///
/// Garde-fou anti mauvais-match AniList (ex. « demon slayer » ≠ « onigiri »),
/// mais assez souple pour accepter les variantes de traduction/formatage.
/// Vrai si, après normalisation, l'un contient l'autre, OU s'ils partagent un
/// préfixe fort, OU si une part suffisante des jetons SIGNIFICATIFS de la
/// requête se retrouve dans le candidat.
bool titlesSimilar(String query, String candidate) {
  final a = normalizeAnimeTitle(query);
  final b = normalizeAnimeTitle(candidate);
  if (a.isEmpty || b.isEmpty) return false;

  // Inclusion directe (sous-titres, suffixes de saison…).
  if (a.contains(b) || b.contains(a)) return true;

  // Préfixe commun fort (>= 8 caractères normalisés) : titres longs qui
  // commencent pareil mais divergent en fin (sous-titre traduit…).
  final prefix = _commonPrefixLength(a, b);
  if (prefix >= 8) return true;

  // Chevauchement de jetons significatifs : au moins ~40% des jetons de la
  // requête (et au minimum un) présents dans le candidat.
  final qt = _titleTokens(query);
  final ct = _titleTokens(candidate);
  if (qt.isEmpty || ct.isEmpty) return false;
  final common = qt.intersection(ct).length;
  return common >= 1 && common * 5 >= qt.length * 2; // >= 40%
}

/// Longueur du plus long préfixe commun entre deux chaînes.
int _commonPrefixLength(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  return i;
}

/// Score de correspondance [0..1000] entre une [query] et un titre [candidate]
/// du catalogue anime-sama. Plus c'est haut, mieux c'est. Sert à choisir le BON
/// résultat parmi ceux qu'anime-sama renvoie (ex. « naruto » ramène
/// [boruto, naruto, naruto shippuden…] — sans scoring on prendrait « boruto »,
/// le premier). 0 = titres sans rapport.
///
/// Barème :
/// - égalité normalisée exacte → 1000 ;
/// - la query EST le titre catalogue à un préfixe près (candidate commence par
///   query) → 900 moins la longueur excédentaire (préfère le plus court, donc
///   l'anime « racine » plutôt qu'une déclinaison) ;
/// - inclusion dans un sens quelconque → 700 moins l'écart de longueur ;
/// - chevauchement de jetons significatifs → proportionnel (0..600) ;
/// - sinon 0.
int titleMatchScore(String query, String candidate) {
  final q = normalizeAnimeTitle(query);
  final c = normalizeAnimeTitle(candidate);
  if (q.isEmpty || c.isEmpty) return 0;

  if (q == c) return 1000;

  // candidate commence par query (« naruto » ⟶ « narutoshippuden ») : bon match,
  // mais on préfère le titre le plus court (le plus proche de la query racine).
  if (c.startsWith(q)) {
    final extra = c.length - q.length;
    return (900 - extra).clamp(700, 900);
  }
  // query commence par candidate (query plus longue, ex. AniList « … Season 3 »).
  if (q.startsWith(c)) {
    final extra = q.length - c.length;
    return (850 - extra).clamp(650, 850);
  }
  // Inclusion ailleurs qu'en préfixe.
  if (c.contains(q) || q.contains(c)) {
    final diff = (c.length - q.length).abs();
    return (700 - diff).clamp(400, 700);
  }

  // Chevauchement de jetons significatifs (0..600).
  final qt = _titleTokens(query);
  final ct = _titleTokens(candidate);
  if (qt.isEmpty || ct.isEmpty) return 0;
  final common = qt.intersection(ct).length;
  if (common == 0) return 0;
  final ratio = common / qt.length; // part des jetons de la query couverts
  return (ratio * 600).round().clamp(1, 600);
}

/// Extrait le slug d'une URL catalogue anime-sama.
///
/// `/catalogue/one-piece/` donne `one-piece`. Tolère l'URL absolue
/// (`https://anime-sama.to/catalogue/...`) et les segments qui suivent le slug
/// (`/catalogue/bleach/saison1/vostfr/` donne `bleach`). Retourne '' si l'URL
/// ne contient pas de segment `/catalogue/<slug>`.
String slugFromCatalogueUrl(String url) {
  final match = RegExp(r'/catalogue/([^/]+)').firstMatch(url);
  return match?.group(1)?.trim() ?? '';
}

/// Identifiant technique positif et stable derivé du slug anime-sama.
///
/// Le slug d'URL est l'identité logique (unique par construction) ; cet entier
/// en est l'identité technique, pour garder les clés étrangères entières des
/// tables de progression. Déterministe (même slug -> même id), toujours > 0.
int animeSamaIdForSlug(String slug) {
  final norm = slug.toLowerCase().trim();
  // FNV-1a 32 bits, déterministe et indépendant de la plateforme.
  var hash = 0x811c9dc5;
  for (final unit in norm.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // Réduit à un positif non nul (31 bits) : jamais 0, jamais négatif.
  final positive = hash & 0x7fffffff;
  return positive == 0 ? 1 : positive;
}

/// Extensions d'image testées dans l'ordre pour une couverture/bannière CDN
/// (le nom de fichier CDN ne porte pas d'extension connue d'avance).
const animeSamaImageExtensions = ['jpg', 'webp', 'png'];

/// URL de couverture (thumbnail) d'un [slug] sur le CDN Anime-Sama, pour une
/// extension [ext] donnée. Les thumbs sont quasi toujours en `.webp`, mais
/// l'appelant teste [animeSamaImageExtensions] dans l'ordre.
///
/// Ex. `link-click` → `.../IMG@img/contenu/thumb/link-click.jpg`.
String animeSamaCoverUrl(String slug, {String ext = 'jpg'}) =>
    'https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/thumb/$slug.$ext';

/// URL de bannière (grande image) d'un [slug] sur le CDN Anime-Sama, pour une
/// extension [ext] donnée. Quasi toujours en `.jpg`.
///
/// Ex. `one-piece` → `.../IMG@img/contenu/one-piece.jpg`.
String animeSamaBannerUrl(String slug, {String ext = 'jpg'}) =>
    'https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/$slug.$ext';
