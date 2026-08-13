/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Une entrée d'historique de visionnage : un LANCEMENT de lecture (clic
/// « Regarder ») d'un épisode d'un anime, horodaté. Sert à afficher l'activité
/// récente dans les statistiques.
library;

class WatchHistoryEntry {
  /// Identifiant en base (null avant insertion).
  final int? id;

  /// Média AniList/anime-sama concerné.
  final int mediaId;

  /// Numéro d'épisode lancé (double pour les demi-épisodes / cohérence DB).
  final double episodeNumber;

  /// Horodatage du lancement de la lecture.
  final DateTime startedAt;

  const WatchHistoryEntry({
    this.id,
    required this.mediaId,
    required this.episodeNumber,
    required this.startedAt,
  });
}
