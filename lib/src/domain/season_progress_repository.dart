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

/// Observateur notifié lors de tout changement de progression ou de nombre total
/// d'épisodes par saison (patron Observateur).
abstract interface class SeasonProgressObserver {
  Future<void> onProgressChanged({
    required int mediaId,
    required int seasonIndex,
    required int watched,
    required int total,
  });
}

class SeasonProgressRepository {
  final SettingsRepository _settings;
  final List<SeasonProgressObserver> _observers = [];

  SeasonProgressRepository(this._settings,
      [List<SeasonProgressObserver>? observers]) {
    if (observers != null) {
      _observers.addAll(observers);
    }
  }

  /// Enregistre un observateur.
  void addObserver(SeasonProgressObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  /// Retire un observateur.
  void removeObserver(SeasonProgressObserver observer) {
    _observers.remove(observer);
  }

  /// Sentinelle « saison entièrement vue » sans connaître le nombre exact
  /// d'épisodes. **Dépréciée** comme valeur d'écriture : on préfère désormais
  /// écrire le nombre RÉEL d'épisodes (cf. [markSeasonFullyWatched]) pour rester
  /// cohérent avec les tuiles (qui comparent au total) et permettre au recheck
  /// de détecter un nouvel épisode. Conservée comme repli (total inconnu) et
  /// pour la rétrocompatibilité en LECTURE (valeurs héritées en base).
  static const int fullyWatchedSentinel = 1 << 20; // 1 048 576

  /// Dernier épisode vu de la saison (0 si aucun).
  Future<int> lastWatched(int anilistId, int seasonIndex) async {
    final raw = await _settings
        .get(SettingsKeys.animeSamaWatchedFor(anilistId, seasonIndex));
    return (raw != null ? int.tryParse(raw) : null) ?? 0;
  }

  /// Fixe le dernier épisode vu de la saison (borné à >= 0).
  /// Notifie les observateurs après enregistrement (patron Observateur).
  Future<void> setLastWatched(
      int anilistId, int seasonIndex, int episode) async {
    final value = episode < 0 ? 0 : episode;
    await _settings.set(
      SettingsKeys.animeSamaWatchedFor(anilistId, seasonIndex),
      '$value',
    );
    final total = await totalEpisodes(anilistId, seasonIndex);
    await _notifyObservers(
      mediaId: anilistId,
      seasonIndex: seasonIndex,
      watched: value,
      total: total,
    );
  }

  /// Nombre total d'épisodes de la saison (0 si inconnu).
  Future<int> totalEpisodes(int anilistId, int seasonIndex) async {
    final raw = await _settings
        .get(SettingsKeys.animeSamaTotalFor(anilistId, seasonIndex));
    return (raw != null ? int.tryParse(raw) : null) ?? 0;
  }

  /// Fixe le nombre total d'épisodes de la saison (borné à >= 0).
  /// Notifie les observateurs après enregistrement (patron Observateur).
  Future<void> setTotalEpisodes(
      int anilistId, int seasonIndex, int count) async {
    final value = count < 0 ? 0 : count;
    await _settings.set(
      SettingsKeys.animeSamaTotalFor(anilistId, seasonIndex),
      '$value',
    );
    final watched = await lastWatched(anilistId, seasonIndex);
    await _notifyObservers(
      mediaId: anilistId,
      seasonIndex: seasonIndex,
      watched: watched,
      total: value,
    );
  }

  /// Marque la saison comme entièrement vue.
  ///
  /// Écrit le nombre RÉEL d'épisodes [episodeCount] (dernier numéro connu) plutôt
  /// qu'une sentinelle : la saison est « vue » tant que `lastWatched >= total`,
  /// et si un nouvel épisode sort (`total` augmente), l'anime redevient
  /// automatiquement « En cours ». Repli sur [fullyWatchedSentinel] uniquement
  /// si le total est inconnu (`episodeCount` null ou <= 0, ex. réseau échoué).
  Future<void> markSeasonFullyWatched(int anilistId, int seasonIndex,
      {int? episodeCount}) async {
    if (episodeCount != null && episodeCount > 0) {
      await _settings.set(
        SettingsKeys.animeSamaTotalFor(anilistId, seasonIndex),
        '$episodeCount',
      );
    }
    final count = (episodeCount != null && episodeCount > 0)
        ? episodeCount
        : fullyWatchedSentinel;
    await setLastWatched(anilistId, seasonIndex, count);
  }

  Future<void> _notifyObservers({
    required int mediaId,
    required int seasonIndex,
    required int watched,
    required int total,
  }) async {
    for (final observer in List<SeasonProgressObserver>.from(_observers)) {
      try {
        await observer.onProgressChanged(
          mediaId: mediaId,
          seasonIndex: seasonIndex,
          watched: watched,
          total: total,
        );
      } catch (_) {
        // Un observateur ne doit pas bloquer la sauvegarde.
      }
    }
  }

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
