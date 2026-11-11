/// Contrôleur partagé d'actualisation en arrière-plan de la bibliothèque
/// (Desktop, Android TV et Mobile).
///
/// À l'ouverture de la bibliothèque et périodiquement :
///  1. Rafraîchit les saisons/épisodes via [AnimeSamaSeasonCacheService]
///     (fusion monotone en base : aucune saison ne disparaît si le scraping
///     échoue ou renvoie une liste tronquée).
///  2. Met à jour `totalEpisodes` sur la dernière saison (ce qui ré-évalue les
///     animes « Terminé » via [SeasonCategoryObserver] et pose le drapeau
///     « nouvel épisode » sur les animes « En cours »).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/season_progress_repository.dart';
import '../../services/animesama_season_cache.dart';

class LibraryRecheckState {
  final bool isRechecking;
  final int current;
  final int total;
  final String? currentTitle;

  const LibraryRecheckState({
    this.isRechecking = false,
    this.current = 0,
    this.total = 0,
    this.currentTitle,
  });

  LibraryRecheckState copyWith({
    bool? isRechecking,
    int? current,
    int? total,
    String? currentTitle,
    bool clearTitle = false,
  }) {
    return LibraryRecheckState(
      isRechecking: isRechecking ?? this.isRechecking,
      current: current ?? this.current,
      total: total ?? this.total,
      currentTitle: clearTitle ? null : (currentTitle ?? this.currentTitle),
    );
  }
}

class LibraryRecheckController extends Notifier<LibraryRecheckState> {
  static const _currentRecheckVersion = '6';
  static const _cooldown = Duration(minutes: 2);
  static const _requestSpacing = Duration(milliseconds: 400);
  static const _completionPause = Duration(milliseconds: 600);

  bool _disposed = false;
  DateTime? _lastFinishedAt;
  Timer? _delayTimer;
  Completer<void>? _delayCompleter;

  @override
  LibraryRecheckState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _delayTimer?.cancel();
      _delayTimer = null;
      final c = _delayCompleter;
      _delayCompleter = null;
      if (c != null && !c.isCompleted) c.complete();
    });
    return const LibraryRecheckState();
  }

  /// Lance une actualisation en arrière-plan (dédupliquée si déjà en cours).
  /// Respecte un court délai anti-rebond entre plateformes sauf si [force] = true.
  Future<void> triggerRecheck({bool force = false}) async {
    if (_disposed || state.isRechecking) return;
    if (!force &&
        _lastFinishedAt != null &&
        DateTime.now().difference(_lastFinishedAt!) < _cooldown) {
      return;
    }

    state = const LibraryRecheckState(
      isRechecking: true,
      current: 0,
      total: 0,
      currentTitle: null,
    );
    try {
      await _normalizeLegacyStatuses();
      await _recheckImpl();
      if (!_disposed) {
        _lastFinishedAt = DateTime.now();
      }
    } catch (_) {
      // Best-effort : un recheck qui échoue ne doit jamais casser l'UI.
    } finally {
      if (!_disposed) {
        state = const LibraryRecheckState();
      }
    }
  }

  Future<bool> _delay(Duration duration) {
    if (_disposed) return Future.value(false);
    final completer = Completer<void>();
    _delayCompleter = completer;
    _delayTimer = Timer(duration, () {
      _delayTimer = null;
      _delayCompleter = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future.then((_) => !_disposed);
  }

  /// Convertit les anciens statuts stockés `current` en `planning` (depuis la
  /// refonte, « En cours » est dérivé dynamiquement de la progression).
  Future<void> _normalizeLegacyStatuses() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final all = await listRepo.getAllEntries();
      var changed = false;
      for (final e in all) {
        if (_disposed) return;
        if (e.status == ListStatus.current) {
          await listRepo.upsertEntry(
              e.copyWith(status: ListStatus.planning, updatedAt: e.updatedAt));
          changed = true;
        }
      }
      if (changed && !_disposed) {
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);
      }
    } catch (_) {/* best-effort */}
  }

  Future<void> _recheckImpl() async {
    final settings = ref.read(settingsRepositoryProvider);
    final recheckVer =
        await settings.get(SettingsKeys.recheckVersion, defaultValue: '1');
    final mustUpgrade = recheckVer != _currentRecheckVersion;

    final listRepo = ref.read(listRepositoryProvider);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final seasonCache = ref.read(animeSamaSeasonCacheProvider);

    final completed = await listRepo.entriesByStatus(ListStatus.completed);
    if (_disposed) return;

    try {
      await ref.read(animeSamaResolverProvider.future);
    } catch (_) {
      return; // résolveur indisponible → pas de recheck.
    }
    if (_disposed) return;

    if (mustUpgrade) {
      await _runMigrationPass(
        settings: settings,
        mediaRepo: mediaRepo,
        listRepo: listRepo,
        seasonProgress: seasonProgress,
        seasonCache: seasonCache,
      );
      if (_disposed) return;
    }

    final planning = await listRepo.entriesByStatus(ListStatus.planning);
    final planningCandidates = <ListEntry>[];
    for (final entry in planning) {
      if (_disposed) return;
      final hasProgress = entry.progress > 0 ||
          await seasonProgress.hasAnyProgress(entry.mediaId);
      if (!hasProgress) continue;
      if (await settings.get(SettingsKeys.newEpisodeFor(entry.mediaId)) ==
          '1') {
        continue;
      }
      planningCandidates.add(entry);
    }

    final total = completed.length + planningCandidates.length;
    if (total == 0) {
      if (mustUpgrade) {
        await settings.set(SettingsKeys.recheckVersion, _currentRecheckVersion);
      }
      return;
    }

    state = state.copyWith(total: total, current: 0, clearTitle: true);

    var changed = false;
    for (final entry in completed) {
      if (_disposed) return;
      final stepChanged = await _recheckCompletedEntry(
        entry: entry,
        mediaRepo: mediaRepo,
        seasonProgress: seasonProgress,
        seasonCache: seasonCache,
      );
      if (stepChanged) changed = true;
      if (!await _delay(_requestSpacing)) return;
    }

    for (final entry in planningCandidates) {
      if (_disposed) return;
      final stepChanged = await _recheckPlanningEntry(
        entry: entry,
        settings: settings,
        mediaRepo: mediaRepo,
        seasonProgress: seasonProgress,
        seasonCache: seasonCache,
      );
      if (stepChanged) changed = true;
      if (!await _delay(_requestSpacing)) return;
    }

    if (_disposed) return;
    await settings.set(SettingsKeys.recheckVersion, _currentRecheckVersion);

    if (changed && !_disposed) {
      ref.invalidate(countByStatusProvider);
      ref.invalidate(entriesByStatusProvider);
      ref.invalidate(listEntryProvider);
    }

    if (!_disposed && state.total > 0) {
      await _delay(_completionPause);
    }
  }

  Future<bool> _recheckCompletedEntry({
    required ListEntry entry,
    required MediaRepository mediaRepo,
    required SeasonProgressRepository seasonProgress,
    required AnimeSamaSeasonCacheService seasonCache,
  }) async {
    final info = await _loadEntryTitle(entry, mediaRepo);
    if (_disposed) return false;
    state = state.copyWith(
      current: state.current + 1,
      currentTitle: info.displayTitle,
    );
    final title = info.searchTitle;
    if (title == null) return false;

    var changed = false;
    try {
      final previousSeasons = await seasonCache.getCachedSeasons(title);
      final seasons = await seasonCache.refreshSeasons(title);
      if (seasons.isNotEmpty) {
        final last = seasons.last;
        final eps = await seasonCache.refreshEpisodes(title, last.index);
        if (eps.isNotEmpty) {
          await seasonProgress.setTotalEpisodes(
              entry.mediaId, last.index, eps.last);
          changed = true;
        }

        // Si de nouvelles saisons (ou saisons restaurées) viennent d'apparaître
        // par rapport au cache précédent, enregistre aussi leur total pour que
        // SeasonCategoryObserver détecte les saisons non vues.
        if (previousSeasons != null &&
            seasons.length > previousSeasons.length) {
          for (final s in seasons) {
            if (_disposed) return changed;
            if (s.index == last.index) continue;
            final knownTotal =
                await seasonProgress.totalEpisodes(entry.mediaId, s.index);
            if (knownTotal <= 0) {
              try {
                final sEps = await seasonCache.refreshEpisodes(title, s.index);
                if (sEps.isNotEmpty) {
                  await seasonProgress.setTotalEpisodes(
                      entry.mediaId, s.index, sEps.last);
                  changed = true;
                }
              } catch (_) {/* best-effort */}
            }
          }
        }
      }
    } catch (_) {
      // Ignore les erreurs individuelles (réseau, anime introuvable…).
    }
    return changed;
  }

  Future<bool> _recheckPlanningEntry({
    required ListEntry entry,
    required SettingsRepository settings,
    required MediaRepository mediaRepo,
    required SeasonProgressRepository seasonProgress,
    required AnimeSamaSeasonCacheService seasonCache,
  }) async {
    final info = await _loadEntryTitle(entry, mediaRepo);
    if (_disposed) return false;
    state = state.copyWith(
      current: state.current + 1,
      currentTitle: info.displayTitle,
    );
    final title = info.searchTitle;
    if (title == null) return false;

    try {
      final seasons = await seasonCache.refreshSeasons(title);
      if (seasons.isEmpty) return false;
      final last = seasons.last;
      final eps = await seasonCache.refreshEpisodes(title, last.index);
      if (eps.isEmpty) return false;

      final watched = await seasonProgress.lastWatched(entry.mediaId, last.index);
      final prevTotal =
          await seasonProgress.totalEpisodes(entry.mediaId, last.index);

      if (watched == 0) {
        await settings.delete(SettingsKeys.newEpisodeFor(entry.mediaId));
        await seasonProgress.setTotalEpisodes(
            entry.mediaId, last.index, eps.last);
        return false;
      }

      if (prevTotal > 0 && eps.last > prevTotal && watched < eps.last) {
        await settings.set(SettingsKeys.newEpisodeFor(entry.mediaId), '1');
      }
      await seasonProgress.setTotalEpisodes(entry.mediaId, last.index, eps.last);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<({String displayTitle, String? searchTitle})> _loadEntryTitle(
    ListEntry entry,
    MediaRepository mediaRepo,
  ) async {
    Media? media;
    try {
      media = await mediaRepo.getMedia(entry.mediaId);
    } catch (_) {}
    final displayTitle = media?.title.preferred ??
        media?.animeSamaTitle ??
        'Anime #${entry.mediaId}';
    final searchTitle = media?.animeSamaTitle ?? media?.title.preferred;
    return (displayTitle: displayTitle, searchTitle: searchTitle);
  }

  Future<void> _runMigrationPass({
    required SettingsRepository settings,
    required MediaRepository mediaRepo,
    required ListRepository listRepo,
    required SeasonProgressRepository seasonProgress,
    required AnimeSamaSeasonCacheService seasonCache,
  }) async {
    final watchedKeys = await settings.entriesWithPrefix('anime_sama_watched:');
    for (final kv in watchedKeys.entries) {
      if (_disposed) return;
      final v = int.tryParse(kv.value) ?? 0;
      if (v < SeasonProgressRepository.fullyWatchedSentinel) continue;
      final parts = kv.key.split(':');
      if (parts.length != 3) continue;
      final id = int.tryParse(parts[1]);
      final seasonIndex = int.tryParse(parts[2]);
      if (id == null || seasonIndex == null) continue;
      try {
        final media = await mediaRepo.getMedia(id);
        final title = media?.animeSamaTitle ?? media?.title.preferred;
        if (title == null) continue;
        final eps = await seasonCache.refreshEpisodes(title, seasonIndex);
        if (eps.isNotEmpty) {
          await seasonProgress.setLastWatched(id, seasonIndex, eps.last);
        }
      } catch (_) {/* réseau : on garde la sentinelle, réessai au prochain */}
    }

    final newEpisodeKeys = await settings.entriesWithPrefix('new_episode:');
    for (final kv in newEpisodeKeys.entries) {
      if (_disposed) return;
      await settings.delete(kv.key);
    }

    final historyRepo = ref.read(watchHistoryRepositoryProvider);
    final progressRepo = ref.read(progressRepositoryProvider);
    for (final kv in watchedKeys.entries) {
      if (_disposed) return;
      final v = int.tryParse(kv.value) ?? 0;
      if (v != 1) continue;
      final parts = kv.key.split(':');
      if (parts.length != 3) continue;
      final id = int.tryParse(parts[1]);
      final seasonIndex = int.tryParse(parts[2]);
      if (id == null || seasonIndex == null || seasonIndex <= 1) continue;
      try {
        final media = await mediaRepo.getMedia(id);
        final title = media?.animeSamaTitle ?? media?.title.preferred;
        if (title == null) continue;
        final eps = await seasonCache.refreshEpisodes(title, seasonIndex);
        if (eps.length <= 1) continue;

        final history = await historyRepo.forMedia(id);
        final prog = await progressRepo.getProgress(id, 1.0);
        final actuallyWatched =
            history.isNotEmpty || (prog != null && prog.positionSeconds > 0);
        if (!actuallyWatched) {
          await seasonProgress.setLastWatched(id, seasonIndex, 0);
          final entry = await listRepo.getEntry(id);
          if (entry != null &&
              entry.progress == 1 &&
              entry.status == ListStatus.planning) {
            await listRepo.upsertEntry(entry.copyWith(
              progress: 0,
              updatedAt: DateTime.now(),
            ));
          }
        }
      } catch (_) {/* best-effort */}
    }
  }
}
