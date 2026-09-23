/// Domaine/logique — détection « série entièrement vue » → statut `completed`.
///
/// Factorise la logique auparavant dupliquée dans player_page, media_detail_page
/// et tv_seasons_list (`_maybeMarkSeriesCompleted`). Service pur (aucun import
/// Flutter) : testable via `dart test`.
library;

import '../../data/repositories/list_repository.dart';
import '../../services/stream_resolver.dart' show AnimeSamaSeason;
import '../models/list_entry.dart';
import '../models/list_status.dart';
import '../season_progress_repository.dart';

class SeriesCompletionService {
  final ListRepository _listRepo;
  final SeasonProgressRepository _seasonProgress;

  const SeriesCompletionService(this._listRepo, this._seasonProgress);

  /// Passe l'anime `completed` si TOUTES ses saisons sont entièrement vues.
  ///
  /// Retourne `true` uniquement si l'anime VIENT de passer terminé (pour
  /// afficher un message à l'utilisateur). Retourne `false` s'il l'était déjà,
  /// si une saison n'est pas finie, ou si les épisodes d'une saison sont
  /// introuvables (on ne peut alors rien affirmer).
  ///
  /// [getEpisodes] fournit les numéros d'épisodes d'une saison (via un provider
  /// Riverpod côté UI, ou directement le resolver). Appelé au plus deux fois par
  /// saison (vérification puis normalisation).
  Future<bool> maybeMarkCompleted({
    required int mediaId,
    required List<AnimeSamaSeason> seasons,
    required Future<List<int>> Function(int seasonIndex) getEpisodes,
  }) async {
    final existing = await _listRepo.getEntry(mediaId);
    if (existing != null && existing.status == ListStatus.completed) {
      return false;
    }
    if (seasons.isEmpty) return false;

    // Cache local des épisodes par saison (évite un double scrape).
    final episodesBySeason = <int, List<int>>{};
    var totalEpisodes = 0;
    for (final s in seasons) {
      final eps = await getEpisodes(s.index);
      if (eps.isEmpty) return false; // saison sans épisodes → on n'affirme rien.
      episodesBySeason[s.index] = eps;
      totalEpisodes += eps.length;
      final watched = await _seasonProgress.lastWatched(mediaId, s.index);
      // « done » comparé au DERNIER NUMÉRO d'épisode (eps.last), cohérent avec
      // markWatched. Sentinelle héritée acceptée pour rétrocompatibilité.
      final done =
          watched >= SeasonProgressRepository.fullyWatchedSentinel ||
              watched >= eps.last;
      if (!done) return false;
    }

    // Toutes vues → normaliser chaque saison au nombre réel d'épisodes. Élimine
    // toute sentinelle résiduelle et garantit que les tuiles affichent
    // « Terminée » de façon cohérente (elles comparent au total).
    for (final s in seasons) {
      final eps = episodesBySeason[s.index]!;
      await _seasonProgress.markSeasonFullyWatched(
        mediaId,
        s.index,
        episodeCount: eps.last,
      );
    }

    final base = existing ??
        ListEntry(
          mediaId: mediaId,
          status: ListStatus.completed,
          updatedAt: DateTime.now(),
        );
    final newProgress =
        totalEpisodes > base.progress ? totalEpisodes : base.progress;
    await _listRepo.upsertEntry(base.copyWith(
      status: ListStatus.completed,
      progress: newProgress,
      updatedAt: DateTime.now(),
    ));
    return true;
  }
}
