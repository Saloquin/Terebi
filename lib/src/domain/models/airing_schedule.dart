/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Planification de diffusion d'un épisode : date/heure de broadcast UTC.
library;

/// Diffusion programmée d'un épisode (AniList `AiringSchedule`).
class AiringSchedule {
  /// ID du média AniList associé.
  final int mediaId;

  /// Numéro de l'épisode qui sera diffusé.
  final int episode;

  /// Date et heure de diffusion en UTC.
  final DateTime airsAt;

  /// `true` si l'utilisateur a déjà reçu une notification pour cet épisode.
  final bool notified;

  const AiringSchedule({
    required this.mediaId,
    required this.episode,
    required this.airsAt,
    this.notified = false,
  });

  /// Retourne `true` si l'épisode a déjà été diffusé au moment [now].
  ///
  /// Le paramètre [now] est requis pour garantir un domaine pur et testable
  /// (pas d'appel à `DateTime.now()` dans le domaine).
  bool hasAired(DateTime now) => airsAt.isBefore(now) || airsAt == now;

  /// Parse un nœud `AiringSchedule` de la réponse GraphQL AniList.
  ///
  /// Champs attendus : `airingAt` (epoch secondes), `episode`.
  /// [mediaId] doit être fourni séparément (non présent dans le nœud AniList).
  factory AiringSchedule.fromAniList(Map<String, dynamic> json, {required int mediaId}) =>
      AiringSchedule(
        mediaId: mediaId,
        episode: json['episode'] as int,
        airsAt: DateTime.fromMillisecondsSinceEpoch(
          (json['airingAt'] as int) * 1000,
          isUtc: true,
        ),
      );

  /// Sérialisation JSON pour le cache local (round-trip avec [AiringSchedule.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'episode': episode,
        'airsAt': airsAt.toIso8601String(),
        'notified': notified,
      };

  factory AiringSchedule.fromJson(Map<String, dynamic> json) => AiringSchedule(
        mediaId: json['mediaId'] as int,
        episode: json['episode'] as int,
        airsAt: DateTime.parse(json['airsAt'] as String),
        notified: (json['notified'] as bool?) ?? false,
      );
}
