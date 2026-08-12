/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Logique de progression de visionnage : « épisode suivant », marquage vu,
/// reprise du dernier épisode. Fonctions pures sans effet de bord ni I/O :
/// elles calculent le nouvel état, la couche data se charge de le persister.
library;

import '../models/list_entry.dart';
import '../models/list_status.dart';
import '../models/media.dart';

/// Résultat du calcul « épisode suivant » (règle produit validée).
///
/// Quand l'utilisateur clique sur « Épisode suivant » depuis l'épisode courant :
/// l'entrée de liste est mise à jour (progress incrémenté, statut ajusté), et
/// [nextEpisode] indique l'épisode à lancer — ou `null` s'il n'y en a pas.
class NextEpisodeOutcome {
  /// Entrée de liste mise à jour (à persister).
  final ListEntry updatedEntry;

  /// Numéro de l'épisode suivant à lancer, ou `null` si l'épisode courant
  /// était le dernier connu (ou média sans épisode suivant, ex. film).
  final int? nextEpisode;

  /// `true` si ce clic a fait passer le média à COMPLETED.
  final bool justCompleted;

  const NextEpisodeOutcome({
    required this.updatedEntry,
    required this.nextEpisode,
    required this.justCompleted,
  });
}

/// Logique pure de progression.
class ProgressService {
  const ProgressService();

  /// Applique la règle « Épisode suivant » (validée avec l'utilisateur) :
  /// - marque l'épisode courant comme vu → `progress = max(progress, currentEpisode)` ;
  /// - si un épisode suivant existe (selon [media.episodes]) : le retourne, statut CURRENT ;
  /// - sinon : pas d'épisode suivant, et si tous les épisodes sont vus → COMPLETED.
  ///
  /// [currentEpisode] est le numéro (1-based) de l'épisode que l'utilisateur vient
  /// de regarder. [now] est injecté pour un `updatedAt` déterministe (testable).
  NextEpisodeOutcome markCurrentWatchedAndAdvance({
    required ListEntry entry,
    required Media media,
    required int currentEpisode,
    required DateTime now,
  }) {
    final totalEpisodes = media.episodes; // null si inconnu
    final newProgress =
        currentEpisode > entry.progress ? currentEpisode : entry.progress;

    // Un film (ou média à 1 épisode) : pas d'épisode suivant, complété.
    final bool hasNext;
    if (media.isMovie) {
      hasNext = false;
    } else if (totalEpisodes == null) {
      // Nombre d'épisodes inconnu : on suppose qu'il peut y avoir une suite.
      hasNext = true;
    } else {
      hasNext = currentEpisode < totalEpisodes;
    }

    final completed = !hasNext &&
        (media.isMovie ||
            (totalEpisodes != null && newProgress >= totalEpisodes));

    // Statut : « En cours » n'est PLUS écrit (dérivé de la progression, cf.
    // effectiveStatus). On ne pose QUE le drapeau `completed` quand tout est vu ;
    // sinon on CONSERVE le statut stocké existant (planning ou statut manuel
    // comme pause/abandonné — qu'on ne doit pas écraser).
    final newStatus = completed ? ListStatus.completed : entry.status;

    final updated = entry.copyWith(
      progress: newProgress,
      status: newStatus,
      updatedAt: now,
    );

    return NextEpisodeOutcome(
      updatedEntry: updated,
      nextEpisode: hasNext ? currentEpisode + 1 : null,
      justCompleted: completed && entry.status != ListStatus.completed,
    );
  }

  /// Épisode à (re)lancer pour « Reprendre » sur une fiche : le prochain épisode
  /// non vu, c.-à-d. `progress + 1`, borné au nombre d'épisodes connu.
  /// Retourne `null` si le média est déjà entièrement vu (rien à reprendre).
  int? resumeEpisode({required ListEntry entry, required Media media}) {
    if (media.isMovie) {
      // Film : à reprendre seulement s'il n'est pas déjà complété.
      return entry.status == ListStatus.completed ? null : 1;
    }
    final total = media.episodes;
    final next = entry.progress + 1;
    if (total != null && next > total) return null; // tout vu
    return next;
  }
}
