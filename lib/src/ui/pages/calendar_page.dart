/// Page Planning hebdomadaire — source **anime-sama** (retour utilisateur).
///
/// - Le planning vient d'anime-sama (jour + heure), pas d'AniList.
/// - Affichage en **colonnes de jour** (Lundi → Dimanche), cartes « poster ».
/// - Chaque carte s'affiche et reste **cliquable immédiatement** (titre + heure) ;
///   la **vignette** AniList se charge en fond (rematch lazy caché). Le rematch
///   se fait aussi au clic (lecture) / à l'ajout perso s'il n'est pas encore prêt.
/// - Toggle **Global / Perso** : Perso = uniquement les anime du planning que tu
///   as marqués « Planifié ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart';
import 'player_page.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Planning hebdomadaire anime-sama, regroupé par jour (ordre anime-sama).
final _planningProvider =
    FutureProvider<List<AnimeSamaPlanningItem>>((ref) async {
  final resolver = await ref.watch(animeSamaResolverProvider.future);
  final settings = ref.watch(settingsRepositoryProvider);
  final langStr =
      await settings.get(SettingsKeys.playbackLanguage, defaultValue: 'vostfr');
  final language =
      langStr == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  return resolver.planning(language: language);
});

/// Rematch (lazy, caché) d'un titre anime-sama vers un [Media] AniList.
/// Sert à afficher la vignette ; le clic n'en dépend pas.
final _mediaForTitleProvider =
    FutureProvider.family<Media?, String>((ref, title) async {
  final matcher = ref.watch(titleMatcherProvider);
  return matcher.match(title);
});

/// IDs des médias en statut PLANNING (pour le toggle Perso + l'état des boutons).
final _planningIdsProvider = FutureProvider<Set<int>>((ref) async {
  final listRepo = ref.watch(listRepositoryProvider);
  final entries = await listRepo.entriesByStatus(ListStatus.planning);
  return entries.map((e) => e.mediaId).toSet();
});

// ---------------------------------------------------------------------------
// Ordre des jours (français)
// ---------------------------------------------------------------------------

const _dayOrder = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

int _dayRank(String day) {
  final idx = _dayOrder.indexWhere((d) => d.toLowerCase() == day.toLowerCase());
  return idx < 0 ? 99 : idx;
}

/// Clé de tri d'une heure « HHhMM » ; les heures vides passent en dernier.
int _timeRank(String time) {
  final m = RegExp(r'^(\d{1,2})h(\d{0,2})$').firstMatch(time.trim());
  if (m == null) return 1 << 20;
  final h = int.tryParse(m.group(1)!) ?? 0;
  final min = int.tryParse(m.group(2)!.isEmpty ? '0' : m.group(2)!) ?? 0;
  return h * 60 + min;
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  // true = GLOBAL (tout le planning), false = PERSO (anime planifiés seulement).
  bool _showGlobal = true;

  @override
  Widget build(BuildContext context) {
    final planningAsync = ref.watch(_planningProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Planning', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Rafraîchir',
                onPressed: () {
                  ref.invalidate(_planningProvider);
                  ref.invalidate(_planningIdsProvider);
                },
              ),
              const SizedBox(width: 4),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Global')),
                  ButtonSegment(value: false, label: Text('Perso')),
                ],
                selected: {_showGlobal},
                onSelectionChanged: (s) => setState(() => _showGlobal = s.first),
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: planningAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _PlanningError(
              message: err is ResolveException ? err.message : err.toString(),
            ),
            data: (items) {
              if (items.isEmpty) return const _PlanningEmpty();
              return _PlanningColumns(items: items, showGlobal: _showGlobal);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Colonnes de jour
// ---------------------------------------------------------------------------

class _PlanningColumns extends ConsumerWidget {
  final List<AnimeSamaPlanningItem> items;
  final bool showGlobal;
  const _PlanningColumns({required this.items, required this.showGlobal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planningIds = ref.watch(_planningIdsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => <int>{},
        );

    final byDay = <String, List<AnimeSamaPlanningItem>>{};
    for (final item in items) {
      byDay.putIfAbsent(item.day, () => []).add(item);
    }

    final days = byDay.keys.toList()
      ..sort((a, b) => _dayRank(a).compareTo(_dayRank(b)));
    for (final list in byDay.values) {
      list.sort((a, b) => _timeRank(a.time).compareTo(_timeRank(b.time)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in days)
            _DayColumn(
              day: day,
              items: byDay[day]!,
              showGlobal: showGlobal,
              planningIds: planningIds,
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String day;
  final List<AnimeSamaPlanningItem> items;
  final bool showGlobal;
  final Set<int> planningIds;
  const _DayColumn({
    required this.day,
    required this.items,
    required this.showGlobal,
    required this.planningIds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          for (final item in items)
            _PlanningCard(
              item: item,
              showGlobal: showGlobal,
              planningIds: planningIds,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte « poster » d'un anime du planning
// ---------------------------------------------------------------------------

class _PlanningCard extends ConsumerStatefulWidget {
  final AnimeSamaPlanningItem item;
  final bool showGlobal;
  final Set<int> planningIds;
  const _PlanningCard({
    required this.item,
    required this.showGlobal,
    required this.planningIds,
  });

  @override
  ConsumerState<_PlanningCard> createState() => _PlanningCardState();
}

class _PlanningCardState extends ConsumerState<_PlanningCard> {
  bool _busy = false;

  /// Rematch AniList à la demande (utilise le cache du provider si déjà résolu).
  Future<Media?> _resolveMedia() =>
      ref.read(titleMatcherProvider).match(widget.item.title);

  Future<void> _launch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final media = await _resolveMedia();
      if (media == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('« ${widget.item.title} » introuvable sur AniList.'),
        ));
        return;
      }
      await _memorizeCurrentSeason(media.anilistId);

      final listRepo = ref.read(listRepositoryProvider);
      final progressRepo = ref.read(progressRepositoryProvider);
      final existing = await listRepo.getEntry(media.anilistId);
      final entry = existing ??
          ListEntry(
            mediaId: media.anilistId,
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          );
      final lastWatched = await progressRepo.lastWatched(media.anilistId);
      final episode = lastWatched?.episodeNumber.toInt() ?? 1;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPage(
            media: media,
            episode: episode,
            entry: entry,
            animeSamaTitle: widget.item.title,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lecture impossible : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mémorise la saison la plus récente d'anime-sama (best-effort).
  Future<void> _memorizeCurrentSeason(int anilistId) async {
    try {
      final resolver = await ref.read(animeSamaResolverProvider.future);
      final seasons = await resolver.listSeasons(title: widget.item.title);
      if (seasons.isNotEmpty) {
        await ref.read(settingsRepositoryProvider).set(
              SettingsKeys.animeSamaSeasonFor(anilistId),
              '${seasons.last.index}',
            );
      }
    } catch (_) {/* best-effort */}
  }

  Future<void> _togglePlanning() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final media = await _resolveMedia();
      if (media == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('« ${widget.item.title} » introuvable sur AniList.'),
        ));
        return;
      }
      final listRepo = ref.read(listRepositoryProvider);
      await ref.read(mediaRepositoryProvider).upsertMedia(media);
      final existing = await listRepo.getEntry(media.anilistId);
      final entry = existing?.copyWith(
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          ) ??
          ListEntry(
            mediaId: media.anilistId,
            status: ListStatus.planning,
            updatedAt: DateTime.now(),
          );
      await listRepo.upsertEntry(entry);
      ref.invalidate(_planningIdsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('« ${widget.item.title} » ajouté au planning perso'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final mediaAsync = ref.watch(_mediaForTitleProvider(item.title));
    final media = mediaAsync.asData?.value;
    final isPlanned =
        media != null && widget.planningIds.contains(media.anilistId);

    // Mode Perso : on ne montre que ce qui est explicitement planifié.
    // (Une carte dont le rematch n'a pas encore résolu n'est pas « planifiée ».)
    if (!widget.showGlobal && !isPlanned) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final coverUrl = media?.coverUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _busy ? null : _launch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Poster ---
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                  if (coverUrl != null)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white38),
                      ),
                    )
                  else
                    Center(
                      child: mediaAsync.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.movie_outlined,
                              color: Colors.white38, size: 32),
                    ),

                  // Overlay play + busy.
                  if (_busy)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  // Bouton ajout planning perso (coin haut-droit).
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          isPlanned
                              ? Icons.bookmark
                              : Icons.bookmark_add_outlined,
                          color: isPlanned ? Colors.orange : Colors.white,
                        ),
                        tooltip: isPlanned
                            ? 'Déjà au planning perso'
                            : 'Ajouter au planning perso',
                        onPressed:
                            (_busy || isPlanned) ? null : _togglePlanning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- Titre + heure ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 13, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(item.time, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// États vide / erreur
// ---------------------------------------------------------------------------

class _PlanningEmpty extends StatelessWidget {
  const _PlanningEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 56, color: Colors.white38),
          SizedBox(height: 12),
          Text('Aucun anime au planning'),
        ],
      ),
    );
  }
}

class _PlanningError extends StatelessWidget {
  final String message;
  const _PlanningError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Planning indisponible',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
