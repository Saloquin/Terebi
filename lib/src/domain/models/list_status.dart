/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Statut d'une entrée de liste, aligné sur AniList `MediaListStatus`.
library;

/// Statut de suivi d'un média dans la bibliothèque de l'utilisateur.
enum ListStatus {
  /// En cours de visionnage (AniList `CURRENT`).
  current,

  /// Prévu / à voir (AniList `PLANNING`).
  planning,

  /// Terminé (AniList `COMPLETED`).
  completed,

  /// En pause (AniList `PAUSED`).
  paused,

  /// Abandonné (AniList `DROPPED`).
  dropped,

  /// En cours de re-visionnage (AniList `REPEATING`).
  repeating;

  /// Valeur AniList correspondante (ex. `CURRENT`).
  String get anilist => switch (this) {
        ListStatus.current => 'CURRENT',
        ListStatus.planning => 'PLANNING',
        ListStatus.completed => 'COMPLETED',
        ListStatus.paused => 'PAUSED',
        ListStatus.dropped => 'DROPPED',
        ListStatus.repeating => 'REPEATING',
      };

  /// Construit un [ListStatus] depuis une valeur AniList. Défaut : [planning].
  static ListStatus fromAniList(String? value) => switch (value) {
        'CURRENT' => ListStatus.current,
        'PLANNING' => ListStatus.planning,
        'COMPLETED' => ListStatus.completed,
        'PAUSED' => ListStatus.paused,
        'DROPPED' => ListStatus.dropped,
        'REPEATING' => ListStatus.repeating,
        _ => ListStatus.planning,
      };
}
