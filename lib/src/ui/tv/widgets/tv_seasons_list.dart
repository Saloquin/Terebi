/// Domaine UI TV — liste verticale des saisons anime-sama d'un anime.
///
/// Reproduit sur TV le comportement desktop de `_AnimeSamaSeasonTile`
/// (media_detail_page.dart) : chaque saison affiche son nom, sa progression
/// (X/Y épisodes + barre) et permet de la lire (OK/Centre) ou de la marquer
/// vue / non vue (bouton dédié focusable au D-pad).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/logic/anime_id.dart';
import '../../../domain/models/list_entry.dart';
import '../../../domain/models/list_status.dart';
import '../../../domain/models/media.dart';
import '../../../domain/season_progress_repository.dart';
import '../../../services/stream_resolver.dart';
import '../../pages/player_page.dart';
import '../../widgets/tv_focusable.dart';

// Progression préchargée pour une saison (lastWatched + total épisodes).
class _SeasonProgress {
  final int lastWatched;
  final int? total;
  const _SeasonProgress({required this.lastWatched, this.total});
}

/// Liste des saisons anime-sama pour un anime, en colonne verticale (TV).
class TvSeasonsList extends ConsumerStatefulWidget {
  final Media media;
  final String searchTitle;

  /// Si vrai, la liste ne défile pas elle-même (shrinkWrap) : à utiliser quand
  /// elle est intégrée dans un Scrollable parent (page détail inline).
  final bool shrinkWrap;

  /// Si vrai, la première saison prend l'autofocus. À laisser faux quand un
  /// autre élément de la page (ex. bouton « Lire ») doit avoir le focus initial.
  final bool autofocusFirst;

  const TvSeasonsList({
    super.key,
    required this.media,
    required this.searchTitle,
    this.shrinkWrap = false,
    this.autofocusFirst = true,
  });

  @override
  ConsumerState<TvSeasonsList> createState() => _TvSeasonsListState();
}

class _TvSeasonsListState extends ConsumerState<TvSeasonsList> {
  // null = pas encore chargé, vide = aucune saison avec progression disponible
  Map<int, _SeasonProgress>? _progressBySeasonIndex;

  Future<void> _loadAllProgress(List<AnimeSamaSeason> seasons) async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final result = <int, _SeasonProgress>{};

    await Future.wait(seasons.map((season) async {
      final last = await seasonProgress.lastWatched(
          widget.media.mediaId, season.index);
      int? total;
      try {
        final eps = await ref.read(animeSamaEpisodesProvider(
          (title: widget.searchTitle, seasonIndex: season.index),
        ).future);
        if (eps.isNotEmpty) total = eps.length;
      } catch (_) {}
      result[season.index] = _SeasonProgress(lastWatched: last, total: total);
    }));

    if (mounted) {
      setState(() => _progressBySeasonIndex = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = ref.watch(animeSamaSeasonsProvider(widget.searchTitle));

    return seasonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text(
          'Saisons indisponibles',
          style: TextStyle(color: Colors.white54),
        ),
      ),
      data: (seasons) {
        if (seasons.isEmpty) {
          return const Center(
            child: Text('Aucune saison',
                style: TextStyle(color: Colors.white54)),
          );
        }

        // Déclenche le chargement global si pas encore fait (ou si les saisons
        // ont changé).
        if (_progressBySeasonIndex == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _loadAllProgress(seasons));
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          itemCount: seasons.length,
          itemBuilder: (context, i) {
            final season = seasons[i];
            final progress = _progressBySeasonIndex![season.index]!;
            return _TvSeasonRow(
              media: widget.media,
              season: season,
              searchTitle: widget.searchTitle,
              isLastSeason: season.index == seasons.last.index,
              autofocus: widget.autofocusFirst && i == 0,
              initialLastWatched: progress.lastWatched,
              initialTotal: progress.total,
              onProgressChanged: (lastWatched) {
                setState(() {
                  _progressBySeasonIndex = {
                    ..._progressBySeasonIndex!,
                    season.index: _SeasonProgress(
                        lastWatched: lastWatched, total: progress.total),
                  };
                });
              },
            );
          },
        );
      },
    );
  }
}

class _TvSeasonRow extends ConsumerStatefulWidget {
  final Media media;
  final AnimeSamaSeason season;
  final String searchTitle;
  final bool isLastSeason;
  final bool autofocus;
  final int initialLastWatched;
  final int? initialTotal;
  final void Function(int lastWatched) onProgressChanged;

  const _TvSeasonRow({
    required this.media,
    required this.season,
    required this.searchTitle,
    required this.isLastSeason,
    required this.autofocus,
    required this.initialLastWatched,
    required this.initialTotal,
    required this.onProgressChanged,
  });

  @override
  ConsumerState<_TvSeasonRow> createState() => _TvSeasonRowState();
}

class _TvSeasonRowState extends ConsumerState<_TvSeasonRow> {
  late int _lastWatched;
  late int? _total;

  // Nœuds explicites : la navigation verticale (haut/bas) circule entre les
  // tuiles ; le bouton « marquer-vu » n'est atteint que latéralement (droite
  // depuis la tuile, gauche pour revenir).
  final FocusNode _tileNode = FocusNode(debugLabel: 'seasonTile');
  final FocusNode _buttonNode = FocusNode(debugLabel: 'seasonButton');

  @override
  void initState() {
    super.initState();
    _lastWatched = widget.initialLastWatched;
    _total = widget.initialTotal;
  }

  @override
  void dispose() {
    _tileNode.dispose();
    _buttonNode.dispose();
    super.dispose();
  }

  Future<void> _reloadWatchedOnly() async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final last = await seasonProgress.lastWatched(
        widget.media.mediaId, widget.season.index);
    if (mounted && last != _lastWatched) {
      setState(() => _lastWatched = last);
      widget.onProgressChanged(last);
    }
  }

  Future<void> _play() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.set(
      SettingsKeys.animeSamaSeasonFor(widget.media.mediaId),
      '${widget.season.index}',
    );

    final listRepo = ref.read(listRepositoryProvider);
    final existingEntry = await listRepo.getEntry(widget.media.mediaId);
    final entry = existingEntry ??
        ListEntry(
          mediaId: widget.media.mediaId,
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        );

    if (!mounted) return;
    final markedFull =
        _lastWatched >= SeasonProgressRepository.fullyWatchedSentinel;
    final startEpisode = markedFull
        ? (_total != null && _total! > 0 ? _total! : 1)
        : _lastWatched + 1;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          media: widget.media,
          episode: startEpisode,
          entry: entry,
          cameFromDetail: true,
          animeSamaTitle: widget.searchTitle,
        ),
      ),
    ).then((_) => _reloadWatchedOnly());
  }

  Future<void> _markThisSeasonWatched() async {
    await ref
        .read(seasonProgressRepositoryProvider)
        .markSeasonFullyWatched(widget.media.mediaId, widget.season.index);
    await _reloadWatchedOnly();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${widget.season.name} » marquée comme vue')),
      );
    }
    await _maybeMarkSeriesCompleted();
  }

  Future<void> _unmarkThisSeason() async {
    await ref
        .read(seasonProgressRepositoryProvider)
        .setLastWatched(widget.media.mediaId, widget.season.index, 0);
    await _reloadWatchedOnly();

    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.mediaId);
      if (existing != null && existing.status == ListStatus.completed) {
        await listRepo.upsertEntry(existing.copyWith(
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        ));
        ref.invalidate(entriesByStatusProvider);
        ref.invalidate(countByStatusProvider);
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${widget.season.name} » marquée non vue')),
      );
    }
  }

  Future<void> _maybeMarkSeriesCompleted() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.mediaId);
      if (existing != null && existing.status == ListStatus.completed) return;

      final seasons = await ref
          .read(animeSamaSeasonsProvider(widget.searchTitle).future);
      if (seasons.isEmpty) return;
      final seasonProgress = ref.read(seasonProgressRepositoryProvider);
      var totalEpisodes = 0;
      for (final s in seasons) {
        final eps = await ref.read(animeSamaEpisodesProvider(
          (title: widget.searchTitle, seasonIndex: s.index),
        ).future);
        if (eps.isEmpty) return;
        totalEpisodes += eps.length;
        final watched =
            await seasonProgress.lastWatched(widget.media.mediaId, s.index);
        final done = watched >= SeasonProgressRepository.fullyWatchedSentinel ||
            watched >= eps.last;
        if (!done) return;
      }
      final base = existing ??
          ListEntry(
            mediaId: widget.media.mediaId,
            status: ListStatus.completed,
            updatedAt: DateTime.now(),
          );
      final newProgress =
          totalEpisodes > base.progress ? totalEpisodes : base.progress;
      await listRepo.upsertEntry(base.copyWith(
        status: ListStatus.completed,
        progress: newProgress,
        updatedAt: DateTime.now(),
      ));
      ref.invalidate(entriesByStatusProvider);
      ref.invalidate(countByStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anime terminé ! 🎉')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final markedFull =
        _lastWatched >= SeasonProgressRepository.fullyWatchedSentinel;
    final done =
        markedFull || (total != null && total > 0 && _lastWatched >= total);
    final ratio = done
        ? 1.0
        : (total != null && total > 0)
            ? (_lastWatched / total).clamp(0.0, 1.0)
            : null;

    final planningTitles = ref.watch(planningTitlesProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <String>{},
        );
    final atPlanning =
        planningTitles.contains(normalizeAnimeTitle(widget.searchTitle));
    final doneLabel =
        (widget.isLastSeason && atPlanning) ? 'À jour' : 'Terminée';

    final progressText = done
        ? doneLabel
        : total != null
            ? '$_lastWatched/$total'
            : '$_lastWatched vu(s)';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Tuile principale : OK = lire la saison. Flèche droite → bouton
          // marquer-vu de la même ligne.
          Expanded(
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _buttonNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TvFocusable(
                focusNode: _tileNode,
                autofocus: widget.autofocus,
                onPressed: _play,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle
                                : Icons.play_circle_outline,
                            color: done ? Colors.green : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.season.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                          ),
                          Text(
                            progressText,
                            style: TextStyle(
                              color: done ? Colors.green : Colors.white70,
                              fontSize: 13,
                              fontWeight: done ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: Colors.white24,
                          color: done
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Bouton séparé : marquer vue / annuler. Exclu de la traversée
          // verticale (haut/bas ne l'atteignent pas) : accessible seulement par
          // flèche droite depuis la tuile ; flèche gauche y revient.
          Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _tileNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FocusTraversalGroup(
              descendantsAreTraversable: false,
              child: TvFocusable(
                focusNode: _buttonNode,
                onPressed: done ? _unmarkThisSeason : _markThisSeasonWatched,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    done ? Icons.remove_done : Icons.done_all,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
