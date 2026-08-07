/// Page Planning hebdomadaire — source **anime-sama** (retour utilisateur).
///
/// - Le planning vient d'anime-sama (jour + heure), pas d'AniList.
/// - Affichage en **colonnes de jour** (Lundi → Dimanche), items triés par heure.
/// - Un clic lance la **lecture directe** : on rematch le titre vers AniList
///   (pour un [Media] exploitable), on mémorise la **saison en cours de sortie**
///   (la plus récente sur anime-sama), et on ouvre le lecteur au dernier épisode vu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../services/stream_resolver.dart';
import 'player_page.dart';

// ---------------------------------------------------------------------------
// Provider planning anime-sama
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

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => ref.invalidate(_planningProvider),
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
              return _PlanningColumns(items: items);
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

class _PlanningColumns extends StatelessWidget {
  final List<AnimeSamaPlanningItem> items;
  const _PlanningColumns({required this.items});

  @override
  Widget build(BuildContext context) {
    // Regroupe par jour.
    final byDay = <String, List<AnimeSamaPlanningItem>>{};
    for (final item in items) {
      byDay.putIfAbsent(item.day, () => []).add(item);
    }

    // Jours présents, ordonnés Lundi→Dimanche.
    final days = byDay.keys.toList()
      ..sort((a, b) => _dayRank(a).compareTo(_dayRank(b)));

    // Tri intra-jour par heure croissante (heures vides en dernier).
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
            _DayColumn(day: day, items: byDay[day]!),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String day;
  final List<AnimeSamaPlanningItem> items;
  const _DayColumn({required this.day, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              day,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          for (final item in items) _PlanningCard(item: item),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte d'un anime du planning
// ---------------------------------------------------------------------------

class _PlanningCard extends ConsumerStatefulWidget {
  final AnimeSamaPlanningItem item;
  const _PlanningCard({required this.item});

  @override
  ConsumerState<_PlanningCard> createState() => _PlanningCardState();
}

class _PlanningCardState extends ConsumerState<_PlanningCard> {
  bool _launching = false;

  Future<void> _launch() async {
    if (_launching) return;
    setState(() => _launching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final matcher = ref.read(titleMatcherProvider);
      final media = await matcher.match(widget.item.title);
      if (media == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('« ${widget.item.title} » introuvable sur AniList.'),
        ));
        return;
      }

      // Saison « en cours de sortie » = la plus récente sur anime-sama.
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
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lecture impossible : $e')));
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  /// Mémorise la saison la plus récente d'anime-sama pour ce média (best-effort).
  Future<void> _memorizeCurrentSeason(int anilistId) async {
    try {
      final resolver = await ref.read(animeSamaResolverProvider.future);
      final seasons = await resolver.listSeasons(title: widget.item.title);
      if (seasons.isNotEmpty) {
        final settings = ref.read(settingsRepositoryProvider);
        await settings.set(
          SettingsKeys.animeSamaSeasonFor(anilistId),
          '${seasons.last.index}',
        );
      }
    } catch (_) {
      // best-effort : le lecteur retombera sur la saison par défaut.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.play_circle_outline),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: item.time.isNotEmpty ? Text(item.time) : null,
        trailing: _launching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: _launching ? null : _launch,
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
