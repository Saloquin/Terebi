/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Progression d'un épisode : position de lecture, durée et état de complétion.
library;

/// Progression de lecture d'un épisode précis pour un média donné.
class EpisodeProgress {
  /// ID du média AniList associé.
  final int mediaId;

  /// Numéro d'épisode (double pour supporter les demi-épisodes, ex. 12.5).
  final double episodeNumber;

  /// `true` si l'épisode a été regardé en entier.
  final bool watched;

  /// Position de reprise en secondes (timestamp exact dans l'épisode).
  final double positionSeconds;

  /// Durée totale de l'épisode en secondes, ou `null` si inconnue.
  final double? durationSeconds;

  /// Date à laquelle l'épisode a été complété, ou `null`.
  final DateTime? completedAt;

  /// Date de dernière mise à jour de cette entrée de progression.
  final DateTime updatedAt;

  const EpisodeProgress({
    required this.mediaId,
    required this.episodeNumber,
    this.watched = false,
    this.positionSeconds = 0,
    this.durationSeconds,
    this.completedAt,
    required this.updatedAt,
  });

  /// Ratio de progression entre 0.0 et 1.0.
  ///
  /// Retourne 0 si la durée est inconnue ou nulle.
  double get progressRatio {
    if (durationSeconds == null || durationSeconds! <= 0) return 0.0;
    final ratio = positionSeconds / durationSeconds!;
    if (ratio < 0) return 0.0;
    if (ratio > 1) return 1.0;
    return ratio;
  }

  /// Sérialisation JSON pour le cache local (round-trip avec [EpisodeProgress.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'episodeNumber': episodeNumber,
        'watched': watched,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) => EpisodeProgress(
        mediaId: json['mediaId'] as int,
        episodeNumber: (json['episodeNumber'] as num).toDouble(),
        watched: (json['watched'] as bool?) ?? false,
        positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
        completedAt: (json['completedAt'] as String?) == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
