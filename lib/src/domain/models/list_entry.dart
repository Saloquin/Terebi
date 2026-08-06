/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Entrée de bibliothèque : un média suivi par l'utilisateur avec son statut,
/// sa progression et sa note personnelle.
library;

import 'list_status.dart';

/// Entrée de la bibliothèque personnelle de l'utilisateur pour un média donné.
class ListEntry {
  /// ID du média AniList associé.
  final int mediaId;

  /// Statut de suivi (en cours, terminé, prévu…).
  final ListStatus status;

  /// Dernier épisode regardé.
  final int progress;

  /// Note personnelle de 1 à 10, ou `null` si non notée.
  final double? score;

  /// `true` si le média est marqué favori.
  final bool favorite;

  /// Notes personnelles libres, ou `null`.
  final String? notes;

  /// `true` si l'entrée est masquée de la page Planning.
  final bool hiddenFromPlanning;

  /// ID de l'entrée côté AniList (`MediaList.id`), ou `null` si locale.
  final int? anilistEntryId;

  /// Date de dernière modification (locale ou AniList).
  final DateTime updatedAt;

  /// Date de dernière synchronisation avec AniList, ou `null` si jamais synchro.
  final DateTime? syncedAt;

  const ListEntry({
    required this.mediaId,
    required this.status,
    this.progress = 0,
    this.score,
    this.favorite = false,
    this.notes,
    this.hiddenFromPlanning = false,
    this.anilistEntryId,
    required this.updatedAt,
    this.syncedAt,
  });

  /// Copie l'entrée en remplaçant les champs fournis (les autres sont conservés).
  ///
  /// Note : ce `copyWith` ne permet pas de repasser un champ nullable à `null`
  /// (limite volontaire, non nécessaire pour la logique de progression).
  ListEntry copyWith({
    int? mediaId,
    ListStatus? status,
    int? progress,
    double? score,
    bool? favorite,
    String? notes,
    bool? hiddenFromPlanning,
    int? anilistEntryId,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) =>
      ListEntry(
        mediaId: mediaId ?? this.mediaId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        score: score ?? this.score,
        favorite: favorite ?? this.favorite,
        notes: notes ?? this.notes,
        hiddenFromPlanning: hiddenFromPlanning ?? this.hiddenFromPlanning,
        anilistEntryId: anilistEntryId ?? this.anilistEntryId,
        updatedAt: updatedAt ?? this.updatedAt,
        syncedAt: syncedAt ?? this.syncedAt,
      );

  /// Parse un nœud `MediaList` de la réponse GraphQL AniList.
  ///
  /// Champs attendus : `id`, `mediaId`, `status`, `progress`, `score`,
  /// `updatedAt` (epoch secondes).
  factory ListEntry.fromAniList(Map<String, dynamic> json) => ListEntry(
        anilistEntryId: json['id'] as int?,
        mediaId: json['mediaId'] as int,
        status: ListStatus.fromAniList(json['status'] as String?),
        progress: (json['progress'] as int?) ?? 0,
        score: (json['score'] as num?)?.toDouble(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          ((json['updatedAt'] as int?) ?? 0) * 1000,
          isUtc: true,
        ),
      );

  /// Sérialisation JSON pour le cache local (round-trip avec [ListEntry.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'status': status.name,
        'progress': progress,
        'score': score,
        'favorite': favorite,
        'notes': notes,
        'hiddenFromPlanning': hiddenFromPlanning,
        'anilistEntryId': anilistEntryId,
        'updatedAt': updatedAt.toIso8601String(),
        'syncedAt': syncedAt?.toIso8601String(),
      };

  factory ListEntry.fromJson(Map<String, dynamic> json) => ListEntry(
        mediaId: json['mediaId'] as int,
        status: ListStatus.values.byName(json['status'] as String? ?? 'planning'),
        progress: (json['progress'] as int?) ?? 0,
        score: (json['score'] as num?)?.toDouble(),
        favorite: (json['favorite'] as bool?) ?? false,
        notes: json['notes'] as String?,
        hiddenFromPlanning: (json['hiddenFromPlanning'] as bool?) ?? false,
        anilistEntryId: json['anilistEntryId'] as int?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        syncedAt: (json['syncedAt'] as String?) == null
            ? null
            : DateTime.parse(json['syncedAt'] as String),
      );
}
