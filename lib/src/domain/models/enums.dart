/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Saison de diffusion et statut de diffusion d'un média (AniList).
library;

/// Saison de diffusion japonaise (AniList `MediaSeason`).
enum AnimeSeason {
  winter,
  spring,
  summer,
  fall;

  String get anilist => switch (this) {
        AnimeSeason.winter => 'WINTER',
        AnimeSeason.spring => 'SPRING',
        AnimeSeason.summer => 'SUMMER',
        AnimeSeason.fall => 'FALL',
      };

  static AnimeSeason? fromAniList(String? value) => switch (value) {
        'WINTER' => AnimeSeason.winter,
        'SPRING' => AnimeSeason.spring,
        'SUMMER' => AnimeSeason.summer,
        'FALL' => AnimeSeason.fall,
        _ => null,
      };
}

/// Statut de diffusion d'un média (AniList `MediaStatus`).
enum ReleaseStatus {
  finished,
  releasing,
  notYetReleased,
  cancelled,
  hiatus,
  unknown;

  String get anilist => switch (this) {
        ReleaseStatus.finished => 'FINISHED',
        ReleaseStatus.releasing => 'RELEASING',
        ReleaseStatus.notYetReleased => 'NOT_YET_RELEASED',
        ReleaseStatus.cancelled => 'CANCELLED',
        ReleaseStatus.hiatus => 'HIATUS',
        ReleaseStatus.unknown => 'UNKNOWN',
      };

  static ReleaseStatus fromAniList(String? value) => switch (value) {
        'FINISHED' => ReleaseStatus.finished,
        'RELEASING' => ReleaseStatus.releasing,
        'NOT_YET_RELEASED' => ReleaseStatus.notYetReleased,
        'CANCELLED' => ReleaseStatus.cancelled,
        'HIATUS' => ReleaseStatus.hiatus,
        _ => ReleaseStatus.unknown,
      };
}
