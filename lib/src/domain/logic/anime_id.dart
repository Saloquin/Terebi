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
