/// Domaine/data léger — progression PAR saison anime-sama.
///
/// anime-sama découpe un anime en saisons (Saison 1, 2, OAV…) alors que la
/// progression d'épisodes classique (`EpisodeProgress`) est globale par média
/// AniList. Pour afficher une barre « N/total » et reprendre au bon endroit
/// PAR SAISON, on stocke le dernier épisode vu de chaque (média, saison) dans
/// les settings (clé [SettingsKeys.animeSamaWatchedFor]).
///
/// Convention : 0 = aucun épisode vu ; N = épisodes 1..N vus. « Terminée » quand
/// N >= total (nombre d'épisodes anime-sama de la saison).
library;

import '../data/repositories/settings_repository.dart';

class SeasonProgressRepository {
  final SettingsRepository _settings;
  const SeasonProgressRepository(this._settings);

  /// Dernier épisode vu de la saison (0 si aucun).
  Future<int> lastWatched(int anilistId, int seasonIndex) async {
    final raw = await _settings
        .get(SettingsKeys.animeSamaWatchedFor(anilistId, seasonIndex));
    return (raw != null ? int.tryParse(raw) : null) ?? 0;
  }

  /// Fixe le dernier épisode vu de la saison (borné à >= 0).
  Future<void> setLastWatched(
      int anilistId, int seasonIndex, int episode) async {
    final value = episode < 0 ? 0 : episode;
    await _settings.set(
      SettingsKeys.animeSamaWatchedFor(anilistId, seasonIndex),
      '$value',
    );
  }

  /// Marque l'épisode [episode] comme vu (n'abaisse jamais le compteur).
  Future<void> markWatched(int anilistId, int seasonIndex, int episode) async {
    final current = await lastWatched(anilistId, seasonIndex);
    if (episode > current) {
      await setLastWatched(anilistId, seasonIndex, episode);
    }
  }
}
