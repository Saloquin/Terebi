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
