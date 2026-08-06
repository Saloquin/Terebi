/// Domaine pur — AUCUN import de package:flutter ici (testable via `dart test`).
///
/// Sonde de validation du pipeline de test. Sera remplacée par les vrais modèles.
library;

/// Formats d'anime (aligné AniList `MediaFormat`).
enum AnimeFormat { tv, tvShort, movie, special, ova, ona, music, unknown }

/// Convertit une valeur AniList (`"TV"`, `"MOVIE"`, ...) en [AnimeFormat].
AnimeFormat animeFormatFromAniList(String? value) {
  switch (value) {
    case 'TV':
      return AnimeFormat.tv;
    case 'TV_SHORT':
      return AnimeFormat.tvShort;
    case 'MOVIE':
      return AnimeFormat.movie;
    case 'SPECIAL':
      return AnimeFormat.special;
    case 'OVA':
      return AnimeFormat.ova;
    case 'ONA':
      return AnimeFormat.ona;
    case 'MUSIC':
      return AnimeFormat.music;
    default:
      return AnimeFormat.unknown;
  }
}
