/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Entrée de bibliothèque : un média suivi par l'utilisateur avec son statut et
/// sa progression.
library;

import 'list_status.dart';

/// Entrée de la bibliothèque personnelle de l'utilisateur pour un média donné.
class ListEntry {
  /// ID du média (dérivé du slug anime-sama).
  final int mediaId;

  /// Statut de suivi (en cours, terminé, prévu…).
  final ListStatus status;

  /// Dernier épisode regardé.
  final int progress;

  /// `true` si l'entrée est masquée de la page Planning.
  final bool hiddenFromPlanning;

  /// Date de dernière modification.
  final DateTime updatedAt;

  /// Nombre total d'épisodes actuellement listés sur Anime-Sama (0 si inconnu).
  final int totalEpisodesOnPage;

  const ListEntry({
    required this.mediaId,
    required this.status,
    this.progress = 0,
    this.hiddenFromPlanning = false,
    required this.updatedAt,
    this.totalEpisodesOnPage = 0,
  });

  /// Statut calculé dynamiquement :
  /// - Respecte les statuts manuels gelants (`paused`, `dropped`, `repeating`).
  /// - `progress == 0` → [ListStatus.planning].
  /// - `totalEpisodesOnPage > 0` et `progress >= totalEpisodesOnPage` → [ListStatus.completed].
  /// - Sinon (en cours de visionnage ou nouveaux épisodes disponibles) → [ListStatus.current].
  ListStatus get calculatedStatus {
    // 1. Choix utilisateur manuel "gelant" prioritaire
    if (status == ListStatus.paused ||
        status == ListStatus.dropped ||
        status == ListStatus.repeating) {
      return status;
    }

    // 2. Aucun épisode vu → Planifié
    if (progress == 0) {
      return ListStatus.planning;
    }

    // 3. Tous les épisodes connus sont vus → Terminé
    if (totalEpisodesOnPage > 0 && progress >= totalEpisodesOnPage) {
      return ListStatus.completed;
    }

    // 4. Par défaut : en cours (progrès > 0 ou nouveaux épisodes sortis)
    return ListStatus.current;
  }

  /// Copie l'entrée en remplaçant les champs fournis (les autres sont conservés).
  ListEntry copyWith({
    int? mediaId,
    ListStatus? status,
    int? progress,
    bool? hiddenFromPlanning,
    DateTime? updatedAt,
    int? totalEpisodesOnPage,
  }) =>
      ListEntry(
        mediaId: mediaId ?? this.mediaId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        hiddenFromPlanning: hiddenFromPlanning ?? this.hiddenFromPlanning,
        updatedAt: updatedAt ?? this.updatedAt,
        totalEpisodesOnPage: totalEpisodesOnPage ?? this.totalEpisodesOnPage,
      );

  /// Sérialisation JSON pour le cache local (round-trip avec [ListEntry.fromJson]).
  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'status': status.name,
        'progress': progress,
        'hiddenFromPlanning': hiddenFromPlanning,
        'updatedAt': updatedAt.toIso8601String(),
        'totalEpisodesOnPage': totalEpisodesOnPage,
      };

  factory ListEntry.fromJson(Map<String, dynamic> json) => ListEntry(
        mediaId: json['mediaId'] as int,
        status:
            ListStatus.values.byName(json['status'] as String? ?? 'planning'),
        progress: (json['progress'] as int?) ?? 0,
        hiddenFromPlanning: (json['hiddenFromPlanning'] as bool?) ?? false,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        totalEpisodesOnPage: (json['totalEpisodesOnPage'] as int?) ?? 0,
      );
}
