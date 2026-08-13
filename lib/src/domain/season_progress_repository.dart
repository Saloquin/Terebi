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

  /// Sentinelle « saison entièrement vue » sans connaître le nombre exact
  /// d'épisodes. Toute barre affiche « Terminée » dès que `lastWatched >= total`
  /// ; cette valeur est >= n'importe quel total réaliste, donc marque la saison
  /// finie sans lancer de requête réseau pour compter les épisodes.
  static const int fullyWatchedSentinel = 1 << 20; // 1 048 576

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

  /// Marque la saison comme entièrement vue via [fullyWatchedSentinel], sans
  /// avoir à compter les épisodes (aucune requête réseau).
  Future<void> markSeasonFullyWatched(int anilistId, int seasonIndex) =>
      setLastWatched(anilistId, seasonIndex, fullyWatchedSentinel);

  /// Marque l'épisode [episode] comme vu (n'abaisse jamais le compteur).
  Future<void> markWatched(int anilistId, int seasonIndex, int episode) async {
    final current = await lastWatched(anilistId, seasonIndex);
    if (episode > current) {
      await setLastWatched(anilistId, seasonIndex, episode);
    }
  }

  /// `true` si l'anime a une progression sur AU MOINS UNE saison (un épisode vu,
  /// ou saison marquée entièrement vue). Local et instantané : scanne les clés
  /// `anime_sama_watched:<mediaId>:*` sans connaître la liste des saisons (donc
  /// sans réseau). Sert à dériver le statut « En cours » à l'affichage.
  Future<bool> hasAnyProgress(int anilistId) async {
    final prefix = 'anime_sama_watched:$anilistId:';
    final entries = await _settings.entriesWithPrefix(prefix);
    for (final v in entries.values) {
      final n = int.tryParse(v) ?? 0;
      if (n > 0) return true;
    }
    return false;
  }
}
