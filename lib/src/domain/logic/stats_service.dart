/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Statistiques de visionnage et estimations de temps (US-90, US-91).
/// Heuristique du besoin utilisateur : un épisode ≈ 24 min, un film (média à un
/// seul épisode) ≈ 2 h. (La source anime-sama ne fournit pas de durée réelle.)
library;

import '../models/list_entry.dart';
import '../models/list_status.dart';
import '../models/media.dart';
import 'effective_status_service.dart';

/// Durées heuristiques par défaut (minutes).
const int kDefaultEpisodeMinutes = 24;
const int kDefaultMovieMinutes = 120;

/// Logique pure de statistiques.
class StatsService {
  const StatsService();

  /// Durée d'un épisode pour [media] : [kDefaultMovieMinutes] si c'est un média
  /// à un seul épisode (film/OAV), [kDefaultEpisodeMinutes] sinon.
  int episodeMinutes(Media media) {
    return media.episodes == 1
        ? kDefaultMovieMinutes
        : kDefaultEpisodeMinutes;
  }

  /// Temps déjà regardé pour une entrée = nombre d'épisodes vus × durée épisode.
  ///
  /// Un anime **« Terminé »** compte pour la série ENTIÈRE. `entry.progress` est
  /// rempli au passage en « Terminé » avec le nombre RÉEL d'épisodes (somme des
  /// saisons anime-sama, cf. media_detail_page / recalcul rétroactif des stats),
  /// donc `progress × durée` est correct. On garde `max(progress, media.episodes)`
  /// comme filet : si anime-sama était indispo (progress non corrigé), on retombe
  /// sur le total Jikan plutôt que sur 0.
  int watchedMinutes({required Media media, required ListEntry entry}) {
    if ((media.episodes == 1)) {
      return entry.status == ListStatus.completed ? episodeMinutes(media) : 0;
    }
    final completed = entry.status == ListStatus.completed;
    final total = media.episodes;
    final episodesWatched = (completed && total != null && total > 0)
        ? (total > entry.progress ? total : entry.progress)
        : entry.progress;
    return episodesWatched * episodeMinutes(media);
  }

  /// Temps total estimé pour finir [media] à partir de l'entrée courante.
  /// `null` si le nombre d'épisodes est inconnu (impossible d'estimer le reste).
  int? remainingMinutes({required Media media, required ListEntry entry}) {
    if ((media.episodes == 1)) {
      return entry.status == ListStatus.completed ? 0 : episodeMinutes(media);
    }
    final total = media.episodes;
    if (total == null) return null;
    final remainingEpisodes = (total - entry.progress).clamp(0, total);
    return remainingEpisodes * episodeMinutes(media);
  }

  /// Temps total regardé sur une bibliothèque (somme sur toutes les entrées).
  /// [mediaById] doit fournir le [Media] pour chaque `entry.mediaId`.
  int totalWatchedMinutes({
    required List<ListEntry> entries,
    required Map<int, Media> mediaById,
  }) {
    var sum = 0;
    for (final e in entries) {
      final m = mediaById[e.mediaId];
      if (m == null) continue;
      sum += watchedMinutes(media: m, entry: e);
    }
    return sum;
  }

  /// Répartition du nombre d'entrées par statut EFFECTIF (calculé). « En cours »
  /// et « Terminé » sont dérivés de la progression (cf. effectiveStatus), pas du
  /// statut stocké — sinon un anime « En cours » (stocké `planning`) serait mal
  /// compté. Les entrées hors listes (effectif null) sont ignorées.
  Map<ListStatus, int> countByStatus(List<ListEntry> entries) {
    final map = <ListStatus, int>{};
    for (final e in entries) {
      final eff = effectiveStatus(entry: e, hasProgress: e.progress > 0);
      if (eff == null) continue;
      map[eff] = (map[eff] ?? 0) + 1;
    }
    return map;
  }

  /// Répartition du temps regardé par genre (minutes).
  Map<String, int> watchedMinutesByGenre({
    required List<ListEntry> entries,
    required Map<int, Media> mediaById,
  }) {
    final map = <String, int>{};
    for (final e in entries) {
      final m = mediaById[e.mediaId];
      if (m == null) continue;
      final minutes = watchedMinutes(media: m, entry: e);
      if (minutes == 0) continue;
      for (final g in m.genres) {
        map[g] = (map[g] ?? 0) + minutes;
      }
    }
    return map;
  }
}
