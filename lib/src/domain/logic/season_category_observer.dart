/// Domaine/logique — observateur de progression/total par saison.
///
/// Implémente le patron Observateur pour réagir aux modifications des variables
/// de progression (`watched`) et de nombre total d'épisodes (`total`).
/// Compare automatiquement ces valeurs et déplace l'anime dans la bonne catégorie :
/// - Si `watched < total` (épisodes restants) et statut `completed` : rétrograde
///   vers `planning` (effectif « En cours ») et active le drapeau `new_episode`.
/// - Si tous les épisodes de toutes les saisons connues sont vus (`watched >= total`) :
///   promeut vers `completed` (« Terminée ») et supprime le drapeau `new_episode`.
/// - Respecte les statuts manuels gelés (pause, abandonné, revisionnage).
library;

import '../../data/repositories/list_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../models/list_status.dart';
import '../season_progress_repository.dart';
import 'effective_status_service.dart';

class SeasonCategoryObserver implements SeasonProgressObserver {
  final ListRepository _listRepo;
  final SettingsRepository _settings;

  const SeasonCategoryObserver({
    required ListRepository listRepo,
    required SettingsRepository settings,
  })  : _listRepo = listRepo,
        _settings = settings;

  @override
  Future<void> onProgressChanged({
    required int mediaId,
    required int seasonIndex,
    required int watched,
    required int total,
  }) async {
    final entry = await _listRepo.getEntry(mediaId);
    if (entry == null) {
      // Anime non présent dans la bibliothèque personnelle.
      return;
    }

    final isFrozen = isFreezingManualStatus(entry.status);

    // Analyse toutes les saisons connues de cet anime pour vérifier
    // s'il reste des épisodes non vus ou si tout est terminé.
    final totalKeys =
        await _settings.entriesWithPrefix('anime_sama_total:$mediaId:');
    final watchedKeys =
        await _settings.entriesWithPrefix('anime_sama_watched:$mediaId:');

    final seasonIndexes = <int>{seasonIndex};
    for (final k in totalKeys.keys) {
      final parts = k.split(':');
      if (parts.length >= 3) {
        final idx = int.tryParse(parts[2]);
        if (idx != null) seasonIndexes.add(idx);
      }
    }
    for (final k in watchedKeys.keys) {
      final parts = k.split(':');
      if (parts.length >= 3) {
        final idx = int.tryParse(parts[2]);
        if (idx != null) seasonIndexes.add(idx);
      }
    }

    var hasUnwatched = false;
    var hasTrackedSeason = false;
    var allSeasonsDone = true;
    var totalEpisodesSum = 0;
    var watchedEpisodesSum = 0;

    for (final idx in seasonIndexes) {
      final tot = (idx == seasonIndex)
          ? total
          : (int.tryParse(totalKeys['anime_sama_total:$mediaId:$idx'] ?? '') ??
              0);
      final w = (idx == seasonIndex)
          ? watched
          : (int.tryParse(
                  watchedKeys['anime_sama_watched:$mediaId:$idx'] ?? '') ??
              0);

      if (tot > 0) {
        hasTrackedSeason = true;
        totalEpisodesSum += tot;
        watchedEpisodesSum += (w > tot ? tot : w);

        final done =
            w >= SeasonProgressRepository.fullyWatchedSentinel || w >= tot;
        if (!done) {
          allSeasonsDone = false;
          hasUnwatched = true;
        }
      } else if (w > 0) {
        watchedEpisodesSum += w;
      }
    }

    if (hasUnwatched) {
      // Au moins une saison a des épisodes non vus.
      if (!isFrozen && entry.status == ListStatus.completed) {
        // L'anime était marqué terminé, mais il a de nouveaux épisodes non vus !
        // Déplace automatiquement dans « En cours » (status = planning).
        final newProgress = watchedEpisodesSum > entry.progress
            ? watchedEpisodesSum
            : entry.progress;
        await _listRepo.upsertEntry(entry.copyWith(
          status: ListStatus.planning,
          progress: newProgress,
          updatedAt: DateTime.now(),
        ));
        await _settings.set(SettingsKeys.newEpisodeFor(mediaId), '1');
      }
    } else if (hasTrackedSeason && allSeasonsDone) {
      // Toutes les saisons connues sont entièrement vues !
      await _settings.delete(SettingsKeys.newEpisodeFor(mediaId));
      if (!isFrozen && entry.status != ListStatus.completed) {
        // Déplace automatiquement dans « Terminée ».
        final newProgress = totalEpisodesSum > entry.progress
            ? totalEpisodesSum
            : entry.progress;
        await _listRepo.upsertEntry(entry.copyWith(
          status: ListStatus.completed,
          progress: newProgress,
          updatedAt: DateTime.now(),
        ));
      }
    }
  }
}
