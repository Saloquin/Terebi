library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart' as domain;
import '../../domain/season_progress_repository.dart';
import '../../services/stream_resolver.dart';
import 'episode_resolver.dart';
import 'player_state.dart';

class PlayerController extends Notifier<PlayerState> {
  static const _resolver = EpisodeResolver();

  // Ces champs sont initialisés dans build() et utilisés par la page via getters.
  late final Player player;
  late final VideoController videoController;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;

  double _lastPersistedWhole = -1;
  Timer? _seekDebounce;
  Timer? _autoPlayTimer;

  domain.Media? _currentMedia;

  @override
  PlayerState build() {
    player = Player();
    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'no'),
    );
    ref.onDispose(_dispose);
    return PlayerState(
      currentEpisode: 0,
      currentEntry: ListEntry(
        mediaId: 0,
        status: ListStatus.planning,
        progress: 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        hiddenFromPlanning: false,
      ),
    );
  }

  // Appelé depuis PlayerPage.initState pour stocker la référence media.
  void setCurrentMedia(domain.Media media) {
    _currentMedia = media;
  }

  Future<void> init({
    required domain.Media media,
    required int requestedEpisode,
    required ListEntry entry,
  }) async {
    _currentMedia = media;
    state = state.copyWith(currentEntry: entry);
    await _loadSettings();
    await _loadSeasonMeta(media: media, requestedEpisode: requestedEpisode);
    _subscribeStreams();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsRepositoryProvider);
    final single =
        await settings.get(SettingsKeys.singleLanguage, defaultValue: '0') ==
            '1';
    state = state.copyWith(singleLanguage: single);
  }

  void _subscribeStreams() {
    _positionSub = player.stream.position.listen((pos) {
      state = state.copyWith(positionSeconds: pos.inMilliseconds / 1000.0);
      _maybePersistPosition();
    });
    _durationSub = player.stream.duration.listen((dur) {
      if (dur.inSeconds > 0) {
        state = state.copyWith(durationSeconds: dur.inMilliseconds / 1000.0);
      }
    });
    _completedSub = player.stream.completed.listen((done) {
      if (done) _onEpisodeCompleted();
    });
  }

  Future<void> _loadSeasonMeta({
    required domain.Media media,
    required int requestedEpisode,
  }) async {
    final title = media.animeSamaTitle ?? media.title.preferred;
    final settings = ref.read(settingsRepositoryProvider);
    final storedStr =
        await settings.get(SettingsKeys.animeSamaSeasonFor(media.mediaId));
    final storedSeason = storedStr != null ? int.tryParse(storedStr) : null;

    final resolver = await ref.read(animeSamaResolverProvider.future);
    final seasons = await resolver.listSeasons(title: title);
    if (seasons.isEmpty) {
      await loadAndPlay(media: media, episode: requestedEpisode);
      return;
    }

    final targetSeason = seasons.firstWhere(
      (s) => s.index == (storedSeason ?? seasons.first.index),
      orElse: () => seasons.first,
    );

    final eps = await resolver.listEpisodes(
      title: title,
      seasonIndex: targetSeason.index,
    );

    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final lastWatched =
        await seasonProgress.lastWatched(media.mediaId, targetSeason.index);

    final initial = _resolver.resolveInitialEpisode(
      requestedEpisode: requestedEpisode,
      episodes: eps,
      lastWatched: lastWatched,
      fullyWatchedSentinel: SeasonProgressRepository.fullyWatchedSentinel,
    );

    final lang = await _preferredLanguage(media: media);
    state = state.copyWith(
      seasonIndex: targetSeason.index,
      seasonName: targetSeason.name,
      episodes: eps,
      currentEpisode: initial,
      initialEpisodeResolved: true,
      language: lang,
    );

    await loadAndPlay(media: media, episode: initial);

    if (!state.singleLanguage) {
      unawaited(_refreshAvailableLangs(
        title: title,
        seasonIndex: targetSeason.index,
        episode: initial,
      ));
    }
  }

  Future<void> loadAndPlay({
    required domain.Media media,
    required int episode,
  }) async {
    if (state.navigating) return;
    state = state.copyWith(loading: true, ready: false, clearError: true);

    final title = media.animeSamaTitle ?? media.title.preferred;
    final resolver = await ref.read(animeSamaResolverProvider.future);

    try {
      final url = await resolver.resolveStreamUrl(
        title: title,
        season: state.seasonIndex,
        episode: episode,
        language: state.language,
      );

      if (url.isEmpty) {
        state = state.copyWith(
            loading: false, error: 'URL introuvable pour cet épisode.');
        return;
      }

      await player.open(Media(url), play: false);
      await _applyMpvProperties();

      final resumePos =
          await _fetchResumePosition(mediaId: media.mediaId, episode: episode);
      if (resumePos != null && resumePos > 5) {
        await player.seek(Duration(seconds: resumePos.toInt()));
      }

      await player.play();
      state = state.copyWith(loading: false, ready: true);

      unawaited(_ensureWatchingStatus(media: media));
      unawaited(_loadSkipTimes(
        title: title,
        episode: episode,
      ));
      if (!state.singleLanguage) {
        unawaited(_refreshAvailableLangs(
          title: title,
          seasonIndex: state.seasonIndex,
          episode: episode,
        ));
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _applyMpvProperties() async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    Future<void> set(String k, String v) async {
      try {
        await platform.setProperty(k, v);
      } catch (_) {/* best-effort */}
    }

    await set('hwdec', 'no');
    await set('hls-bitrate', 'max');
    await set('hr-seek', 'yes');
    await set('hr-seek-framedrop', 'no');
    await set('demuxer-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
    await set('demuxer-max-back-bytes', '${16 * 1024 * 1024}');
    await set('demuxer-max-bytes', '${64 * 1024 * 1024}');
  }

  Future<double?> _fetchResumePosition(
      {required int mediaId, required int episode}) async {
    final repo = ref.read(progressRepositoryProvider);
    final prog = await repo.getProgress(mediaId, episode.toDouble());
    if (prog == null) return null;
    if (prog.durationSeconds != null && prog.durationSeconds! > 0) {
      if (prog.positionSeconds / prog.durationSeconds! > 0.9) return null;
    }
    return prog.positionSeconds;
  }

  Future<void> goToEpisode({
    required domain.Media media,
    required int episode,
  }) async {
    if (state.navigating) return;
    state = state.copyWith(navigating: true, clearAutoPlay: true);
    _cancelAutoPlay();

    try {
      if (episode > state.currentEpisode) {
        await _markCurrentWatched(media: media);
      } else {
        await _rewindProgressTo(media: media, episode: episode);
      }

      state = state.copyWith(
        currentEpisode: episode,
        positionSeconds: 0,
        clearDuration: true,
      );
      await loadAndPlay(media: media, episode: episode);
    } finally {
      if (state.navigating) {
        state = state.copyWith(navigating: false);
      }
    }
  }

  Future<void> goToNextEpisode({required domain.Media media}) async {
    final next = state.nextEpisode;
    if (next == null) return;
    await goToEpisode(media: media, episode: next);
  }

  Future<void> goToPrevEpisode({required domain.Media media}) async {
    final prev = state.prevEpisode;
    if (prev == null) return;
    await goToEpisode(media: media, episode: prev);
  }

  Future<void> _markCurrentWatched({required domain.Media media}) async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    await seasonProgress.markWatched(
        media.mediaId, state.seasonIndex, state.currentEpisode);

    final repo = ref.read(progressRepositoryProvider);
    final dur = state.durationSeconds;
    await repo.upsertProgress(EpisodeProgress(
      mediaId: media.mediaId,
      episodeNumber: state.currentEpisode.toDouble(),
      watched: true,
      positionSeconds: dur ?? 0,
      durationSeconds: dur,
      updatedAt: DateTime.now(),
    ));
    await _invalidateStatusProviders();
  }

  Future<void> _rewindProgressTo({
    required domain.Media media,
    required int episode,
  }) async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final currentWatched =
        await seasonProgress.lastWatched(media.mediaId, state.seasonIndex);

    if (currentWatched >= SeasonProgressRepository.fullyWatchedSentinel ||
        currentWatched >= episode) {
      await seasonProgress.setLastWatched(
          media.mediaId, state.seasonIndex, episode - 1);

      final listRepo = ref.read(listRepositoryProvider);
      final entry = await listRepo.getEntry(media.mediaId);
      if (entry?.status == ListStatus.completed) {
        await listRepo.upsertEntry(
            entry!.copyWith(status: ListStatus.current));
        await _invalidateStatusProviders();
      }
    }
  }

  void _maybePersistPosition() {
    final whole = state.positionSeconds.toInt();
    if (whole == _lastPersistedWhole.toInt()) return;
    if (whole % 5 != 0) return;
    _lastPersistedWhole = whole.toDouble();
    unawaited(_persistPosition());
  }

  Future<void> _persistPosition() async {
    if (state.currentEntry.mediaId == 0) return;
    final repo = ref.read(progressRepositoryProvider);
    await repo.upsertProgress(EpisodeProgress(
      mediaId: state.currentEntry.mediaId,
      episodeNumber: state.currentEpisode.toDouble(),
      watched: false,
      positionSeconds: state.positionSeconds,
      durationSeconds: state.durationSeconds,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _invalidateStatusProviders() async {
    ref.invalidate(countByStatusProvider);
    ref.invalidate(entriesByStatusProvider);
    ref.invalidate(listEntryProvider);
  }

  void _onEpisodeCompleted() {
    if (_currentMedia == null) return;
    unawaited(_markCurrentWatched(media: _currentMedia!));
    _maybeStartAutoPlay();
  }

  void _maybeStartAutoPlay() {
    if (state.isLastEpisode || state.nextEpisode == null) return;
    _startAutoPlayCountdown();
  }

  void _startAutoPlayCountdown() {
    state = state.copyWith(autoPlayCountdown: 5);
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = (state.autoPlayCountdown ?? 0) - 1;
      if (remaining <= 0) {
        t.cancel();
        state = state.copyWith(clearAutoPlay: true);
        if (_currentMedia != null) {
          unawaited(goToNextEpisode(media: _currentMedia!));
        }
      } else {
        state = state.copyWith(autoPlayCountdown: remaining);
      }
    });
  }

  void cancelAutoPlay() {
    _cancelAutoPlay();
    state = state.copyWith(clearAutoPlay: true);
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  Future<PlaybackLanguage> _preferredLanguage({
    required domain.Media media,
  }) async {
    final settings = ref.read(settingsRepositoryProvider);
    final perAnime =
        await settings.get(SettingsKeys.animeSamaLangFor(media.mediaId));
    if (perAnime != null) {
      return perAnime == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
    }
    final global = await settings.get(SettingsKeys.playbackLanguage,
        defaultValue: 'vostfr');
    return global == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  }

  Future<void> switchLanguage({
    required domain.Media media,
    required PlaybackLanguage lang,
  }) async {
    state = state.copyWith(language: lang);
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.animeSamaLangFor(media.mediaId),
            lang == PlaybackLanguage.vf ? 'vf' : 'vostfr');
    if (state.ready) {
      await loadAndPlay(media: media, episode: state.currentEpisode);
    }
  }

  Future<void> _refreshAvailableLangs({
    required String title,
    required int seasonIndex,
    required int episode,
  }) async {
    try {
      final langs = await ref.read(
        animeSamaLanguagesProvider((
          title: title,
          seasonIndex: seasonIndex,
          episode: episode,
        )).future,
      );
      state = state.copyWith(availableLanguages: langs);
    } catch (_) {}
  }

  Future<void> _loadSkipTimes({
    required String title,
    required int episode,
  }) async {
    try {
      final times = await ref.read(
        animeSamaSkipTimesProvider((
          title: title,
          seasonIndex: state.seasonIndex,
          episode: episode,
          malId: null,
        )).future,
      );
      state = state.copyWith(skipTimes: times);
    } catch (_) {
      state = state.copyWith(skipTimes: const SkipTimes());
    }
  }

  void seekTo(double seconds) {
    player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed);
    player.setRate(speed);
  }

  Future<void> _ensureWatchingStatus({required domain.Media media}) async {
    final listRepo = ref.read(listRepositoryProvider);
    final existing = await listRepo.getEntry(media.mediaId);
    if (existing == null) {
      await listRepo.upsertEntry(ListEntry(
        mediaId: media.mediaId,
        status: ListStatus.current,
        progress: 0,
        updatedAt: DateTime.now(),
        hiddenFromPlanning: false,
      ));
      await _invalidateStatusProviders();
    }
  }

  Future<void> _dispose() async {
    _seekDebounce?.cancel();
    _cancelAutoPlay();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completedSub?.cancel();
    try {
      await _persistPosition();
    } catch (_) {}
    await player.dispose();
  }
}
