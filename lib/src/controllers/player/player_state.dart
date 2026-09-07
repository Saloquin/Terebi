library;

import '../../domain/models/list_entry.dart';
import '../../services/stream_resolver.dart';

class PlayerState {
  final bool loading;
  final bool ready;
  final String? error;
  final int currentEpisode;
  final int seasonIndex;
  final String? seasonName;
  final List<int> episodes;
  final bool initialEpisodeResolved;
  final bool navigating;
  final double positionSeconds;
  final double? durationSeconds;
  final double speed;
  final SkipTimes skipTimes;
  final PlaybackLanguage language;
  final Set<PlaybackLanguage> availableLanguages;
  final bool singleLanguage;
  final int? autoPlayCountdown;
  final ListEntry currentEntry;

  const PlayerState({
    this.loading = false,
    this.ready = false,
    this.error,
    required this.currentEpisode,
    this.seasonIndex = 1,
    this.seasonName,
    this.episodes = const [],
    this.initialEpisodeResolved = false,
    this.navigating = false,
    this.positionSeconds = 0,
    this.durationSeconds,
    this.speed = 1.0,
    this.skipTimes = const SkipTimes(),
    this.language = PlaybackLanguage.vostfr,
    this.availableLanguages = const {},
    this.singleLanguage = false,
    this.autoPlayCountdown,
    required this.currentEntry,
  });

  PlayerState copyWith({
    bool? loading,
    bool? ready,
    String? error,
    int? currentEpisode,
    int? seasonIndex,
    String? seasonName,
    List<int>? episodes,
    bool? initialEpisodeResolved,
    bool? navigating,
    double? positionSeconds,
    double? durationSeconds,
    double? speed,
    SkipTimes? skipTimes,
    PlaybackLanguage? language,
    Set<PlaybackLanguage>? availableLanguages,
    bool? singleLanguage,
    int? autoPlayCountdown,
    ListEntry? currentEntry,
    bool clearError = false,
    bool clearAutoPlay = false,
    bool clearDuration = false,
    bool clearSeasonName = false,
  }) {
    return PlayerState(
      loading: loading ?? this.loading,
      ready: ready ?? this.ready,
      error: clearError ? null : error ?? this.error,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      seasonIndex: seasonIndex ?? this.seasonIndex,
      seasonName: clearSeasonName ? null : seasonName ?? this.seasonName,
      episodes: episodes ?? this.episodes,
      initialEpisodeResolved:
          initialEpisodeResolved ?? this.initialEpisodeResolved,
      navigating: navigating ?? this.navigating,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds:
          clearDuration ? null : durationSeconds ?? this.durationSeconds,
      speed: speed ?? this.speed,
      skipTimes: skipTimes ?? this.skipTimes,
      language: language ?? this.language,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      singleLanguage: singleLanguage ?? this.singleLanguage,
      autoPlayCountdown:
          clearAutoPlay ? null : autoPlayCountdown ?? this.autoPlayCountdown,
      currentEntry: currentEntry ?? this.currentEntry,
    );
  }

  bool get isLastEpisode =>
      episodes.isNotEmpty && currentEpisode >= episodes.last;

  int? get nextEpisode {
    if (episodes.isEmpty) return null;
    final idx = episodes.indexOf(currentEpisode);
    if (idx < 0 || idx >= episodes.length - 1) return null;
    return episodes[idx + 1];
  }

  int? get prevEpisode {
    if (episodes.isEmpty) return null;
    final idx = episodes.indexOf(currentEpisode);
    if (idx <= 0) return null;
    return episodes[idx - 1];
  }
}
