/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Utilitaires de titre : nettoyage pour la recherche, extraction du numéro de
/// saison depuis un titre AniList (qui inclut souvent « Saison N », « 2nd
/// Season », etc.).
library;

/// Résultat de [parseSeasonFromTitle] : titre de base + numéro de saison.
class TitleSeason {
  /// Titre débarrassé du suffixe de saison (pour la recherche).
  final String baseTitle;

  /// Numéro de saison déduit (1 par défaut si aucun trouvé).
  final int season;

  const TitleSeason(this.baseTitle, this.season);

  @override
  bool operator ==(Object other) =>
      other is TitleSeason &&
      other.baseTitle == baseTitle &&
      other.season == season;

  @override
  int get hashCode => Object.hash(baseTitle, season);

  @override
  String toString() => 'TitleSeason($baseTitle, $season)';
}

const Map<String, int> _romanToInt = {
  'i': 1,
  'ii': 2,
  'iii': 3,
  'iv': 4,
  'v': 5,
  'vi': 6,
  'vii': 7,
  'viii': 8,
};

/// Nettoie un titre AniList pour la recherche : retire les suffixes de saison
/// (« Saison 2 », « Season 2 », « 2nd Season », « Part 2 », chiffres romains) et
/// les sous-titres après « : ».
String cleanSearchTitle(String title) {
  var t = title.trim();
  final patterns = <RegExp>[
    RegExp(r'\s+(saison|season)\s+\d+$', caseSensitive: false),
    RegExp(r'\s+\d+(st|nd|rd|th)\s+season$', caseSensitive: false),
    RegExp(r'\s+(part|partie)\s+\d+$', caseSensitive: false),
    RegExp(r'\s+(season|saison)\s+[ivx]+$', caseSensitive: false),
    RegExp(r'\s*:\s*.*$'), // sous-titre après ':'
  ];
  for (final p in patterns) {
    t = t.replaceAll(p, '');
  }
  return t.trim();
}

/// Déduit le numéro de saison depuis un titre et renvoie le titre de base.
///
/// Exemples : « Dr Stone Saison 2 » → (« Dr Stone », 2) ; « Overlord 2nd Season »
/// → (« Overlord », 2) ; « One Piece » → (« One Piece », 1).
TitleSeason parseSeasonFromTitle(String title) {
  final t = title.trim();
  int? season;

  // « Saison N » / « Season N »
  final arabic = RegExp(r'(saison|season)\s+(\d+)\s*$', caseSensitive: false)
      .firstMatch(t);
  if (arabic != null) {
    season = int.tryParse(arabic.group(2)!);
  }

  // « Nth Season »
  final ordinal =
      RegExp(r'(\d+)(st|nd|rd|th)\s+season\s*$', caseSensitive: false).firstMatch(t);
  if (season == null && ordinal != null) {
    season = int.tryParse(ordinal.group(1)!);
  }

  // « Season IV » (chiffres romains)
  final roman = RegExp(r'(season|saison)\s+([ivx]+)\s*$', caseSensitive: false)
      .firstMatch(t);
  if (season == null && roman != null) {
    season = _romanToInt[roman.group(2)!.toLowerCase()];
  }

  return TitleSeason(cleanSearchTitle(t), season ?? 1);
}
