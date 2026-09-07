library;

/// Logique pure de résolution de l'épisode initial depuis la progression.
/// Aucun import Flutter. Testable via `dart test`.
class EpisodeResolver {
  const EpisodeResolver();

  int resolveInitialEpisode({
    required int requestedEpisode,
    required List<int> episodes,
    required int lastWatched,
    required int fullyWatchedSentinel,
  }) {
    if (episodes.isEmpty) return requestedEpisode;
    if (episodes.contains(requestedEpisode)) return requestedEpisode;
    if (lastWatched >= fullyWatchedSentinel) return episodes.first;
    if (lastWatched > 0) {
      return episodes.firstWhere(
        (e) => e > lastWatched,
        orElse: () => episodes.first,
      );
    }
    return episodes.first;
  }

  int? nextEpisode(List<int> episodes, int current) {
    final idx = episodes.indexOf(current);
    if (idx < 0 || idx >= episodes.length - 1) return null;
    return episodes[idx + 1];
  }

  int? prevEpisode(List<int> episodes, int current) {
    final idx = episodes.indexOf(current);
    if (idx <= 0) return null;
    return episodes[idx - 1];
  }
}
