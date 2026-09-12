/// Domaine UI TV — liste verticale des saisons anime-sama d'un anime.
///
/// Reproduit sur TV le comportement desktop de `_AnimeSamaSeasonTile`
/// (media_detail_page.dart) : chaque saison affiche son nom, sa progression
/// (X/Y épisodes + barre) et permet de la lire (OK/Centre) ou de la marquer
/// vue / non vue (bouton dédié focusable au D-pad).
library;

import 'package:flutter/material.dart';
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

/// Liste des saisons anime-sama pour un anime, en colonne verticale (TV).
class TvSeasonsList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonsAsync = ref.watch(animeSamaSeasonsProvider(searchTitle));

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
            child:
                Text('Aucune saison', style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          itemCount: seasons.length,
          itemBuilder: (context, i) => _TvSeasonRow(
            media: media,
            season: seasons[i],
            searchTitle: searchTitle,
            isLastSeason: seasons[i].index == seasons.last.index,
            autofocus: autofocusFirst && i == 0,
          ),
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

  const _TvSeasonRow({
    required this.media,
    required this.season,
    required this.searchTitle,
    required this.isLastSeason,
    required this.autofocus,
  });

  @override
  ConsumerState<_TvSeasonRow> createState() => _TvSeasonRowState();
}

class _TvSeasonRowState extends ConsumerState<_TvSeasonRow> {
  int _lastWatched = 0; // dernier épisode vu (0 = rien)
  int? _total; // nombre d'épisodes anime-sama de la saison
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgress());
  }

  Future<void> _loadProgress() async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final last = await seasonProgress.lastWatched(
        widget.media.mediaId, widget.season.index);

    int? total;
    try {
      final eps = await ref.read(animeSamaEpisodesProvider(
        (title: widget.searchTitle, seasonIndex: widget.season.index),
      ).future);
      if (eps.isNotEmpty) total = eps.length;
    } catch (_) {/* total inconnu → barre indéterminée */}

    if (mounted) {
      setState(() {
        _lastWatched = last;
        _total = total;
        _loaded = true;
      });
    }
  }

  Future<void> _reloadWatchedOnly() async {
    final seasonProgress = ref.read(seasonProgressRepositoryProvider);
    final last = await seasonProgress.lastWatched(
        widget.media.mediaId, widget.season.index);
    if (mounted && last != _lastWatched) {
      setState(() => _lastWatched = last);
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
    ).then((_) => _loadProgress());
  }

  /// Marque cette saison entièrement vue, puis tente de passer l'anime
  /// « Terminé » si c'était la dernière saison manquante.
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

  /// Annule le marquage « vue » : remet à 0 et repasse l'anime « En cours »
  /// s'il était « Terminé ».
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
    } catch (_) {/* best-effort */}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${widget.season.name} » marquée non vue')),
      );
    }
  }

  /// Passe l'anime « Terminé » si TOUTES ses saisons anime-sama sont vues.
  Future<void> _maybeMarkSeriesCompleted() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.mediaId);
      if (existing != null && existing.status == ListStatus.completed) return;

      final seasons =
          await ref.read(animeSamaSeasonsProvider(widget.searchTitle).future);
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
    } catch (_) {/* best-effort */}
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

    final progressText = !_loaded
        ? '…'
        : done
            ? doneLabel
            : total != null
                ? '$_lastWatched/$total'
                : '$_lastWatched vu(s)';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Tuile principale : OK = lire la saison.
          Expanded(
            child: TvFocusable(
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
                          done ? Icons.check_circle : Icons.play_circle_outline,
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
                        value: ratio, // null → barre indéterminée
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
          const SizedBox(width: 12),
          // Bouton séparé : marquer vue / annuler (focusable au D-pad).
          if (_loaded)
            TvFocusable(
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
        ],
      ),
    );
  }
}
