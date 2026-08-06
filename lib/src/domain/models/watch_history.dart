/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Session de visionnage : une plage horaire pendant laquelle l'utilisateur
/// a regardé un épisode donné.
library;

/// Une session de visionnage d'un épisode (début, fin, durée regardée).
class WatchHistory {
  /// ID du média AniList associé.
  final int mediaId;

  /// Numéro d'épisode visionné (double pour supporter les demi-épisodes).
  final double episodeNumber;

  /// Date et heure de début du visionnage.
  final DateTime startedAt;

  /// Date et heure de fin du visionnage, ou `null` si la session est en cours.
  final DateTime? endedAt;

  /// Secondes effectivement regardées (peut être inférieur à la durée totale).
  final double watchedSeconds;

  const WatchHistory({
    required this.mediaId,
    required this.episodeNumber,
    required this.startedAt,
    this.endedAt,
    this.watchedSeconds = 0,
  });

  /// Sérialisation JSON pour le cache local (round-trip avec [WatchHistory.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'episodeNumber': episodeNumber,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'watchedSeconds': watchedSeconds,
      };

  factory WatchHistory.fromJson(Map<String, dynamic> json) => WatchHistory(
        mediaId: json['mediaId'] as int,
        episodeNumber: (json['episodeNumber'] as num).toDouble(),
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: (json['endedAt'] as String?) == null
            ? null
            : DateTime.parse(json['endedAt'] as String),
        watchedSeconds: (json['watchedSeconds'] as num?)?.toDouble() ?? 0,
      );
}
