/// Page Dashboard statistiques de visionnage (US-90/91).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

final _statsDataProvider = FutureProvider<_StatsData>((ref) async {
  final listRepo = ref.watch(listRepositoryProvider);
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final statsService = ref.watch(statsServiceProvider);

  // Collecte toutes les entrées de tous les statuts.
  final allEntries = <ListEntry>[];
  for (final status in ListStatus.values) {
    allEntries.addAll(await listRepo.entriesByStatus(status));
  }

  // Construit la map mediaId → Media.
  final mediaById = <int, Media>{};
  for (final entry in allEntries) {
    if (!mediaById.containsKey(entry.mediaId)) {
      final media = await mediaRepo.getMedia(entry.mediaId);
      if (media != null) mediaById[entry.mediaId] = media;
    }
  }

  return _StatsData(
    totalMinutes: statsService.totalWatchedMinutes(
      entries: allEntries,
      mediaById: mediaById,
    ),
    countByStatus: statsService.countByStatus(allEntries),
    minutesByGenre: statsService.watchedMinutesByGenre(
      entries: allEntries,
      mediaById: mediaById,
    ),
  );
});

class _StatsData {
  final int totalMinutes;
  final Map<ListStatus, int> countByStatus;
  final Map<String, int> minutesByGenre;

  const _StatsData({
    required this.totalMinutes,
    required this.countByStatus,
    required this.minutesByGenre,
  });
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_statsDataProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger les statistiques',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final totalEntries =
            data.countByStatus.values.fold(0, (a, b) => a + b);
        if (totalEntries == 0) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart, size: 64, color: Colors.white38),
                SizedBox(height: 12),
                Text('Aucune entrée dans la bibliothèque'),
              ],
            ),
          );
        }
        return _StatsBody(data: data);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Corps principal
// ---------------------------------------------------------------------------

class _StatsBody extends StatelessWidget {
  final _StatsData data;
  const _StatsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final sortedGenres = data.minutesByGenre.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(10).toList();
    final maxGenreMinutes = topGenres.isEmpty ? 1 : topGenres.first.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Statistiques',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),

        // --- Temps total ---
        _StatCard(
          icon: Icons.access_time,
          title: 'Temps total regardé',
          value: _formatMinutes(data.totalMinutes),
        ),
        const SizedBox(height: 12),

        // --- Séries terminées ---
        _StatCard(
          icon: Icons.check_circle_outline,
          title: 'Séries terminées',
          value: '${data.countByStatus[ListStatus.completed] ?? 0}',
        ),
        const SizedBox(height: 20),

        // --- Répartition par statut ---
        Text(
          'Répartition par statut',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _StatusBars(countByStatus: data.countByStatus),
        const SizedBox(height: 20),

        // --- Top genres ---
        if (topGenres.isNotEmpty) ...[
          Text(
            'Top genres (temps regardé)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final entry in topGenres)
            _GenreBar(
              genre: entry.key,
              minutes: entry.value,
              maxMinutes: maxGenreMinutes,
            ),
        ],
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes == 0) return '0 min';
    final days = minutes ~/ (60 * 24);
    final hours = (minutes % (60 * 24)) ~/ 60;
    final mins = minutes % 60;
    if (days > 0) return hours > 0 ? '$days j ${hours}h' : '$days j';
    if (hours > 0) return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    return '${mins}m';
  }
}

// ---------------------------------------------------------------------------
// Carte statistique simple
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 32, color: colorScheme.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Répartition par statut (barres)
// ---------------------------------------------------------------------------

const _statusLabels = {
  ListStatus.current: 'En cours',
  ListStatus.planning: 'Planifié',
  ListStatus.completed: 'Terminé',
  ListStatus.paused: 'En pause',
  ListStatus.dropped: 'Abandonné',
  ListStatus.repeating: 'Re-vision',
};

class _StatusBars extends StatelessWidget {
  final Map<ListStatus, int> countByStatus;
  const _StatusBars({required this.countByStatus});

  @override
  Widget build(BuildContext context) {
    final total = countByStatus.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        for (final status in ListStatus.values)
          if ((countByStatus[status] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StatusRow(
                label: _statusLabels[status] ?? status.name,
                count: countByStatus[status] ?? 0,
                total: total,
                color: _statusColor(status),
              ),
            ),
      ],
    );
  }

  static Color _statusColor(ListStatus s) => switch (s) {
        ListStatus.current => Colors.blue,
        ListStatus.planning => Colors.orange,
        ListStatus.completed => Colors.green,
        ListStatus.paused => Colors.amber,
        ListStatus.dropped => Colors.red,
        ListStatus.repeating => Colors.purple,
      };
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Barre par genre
// ---------------------------------------------------------------------------

class _GenreBar extends StatelessWidget {
  final String genre;
  final int minutes;
  final int maxMinutes;

  const _GenreBar({
    required this.genre,
    required this.minutes,
    required this.maxMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              genre,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                valueColor:
                    AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              _fmt(minutes),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
