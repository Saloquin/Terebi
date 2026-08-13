/// Page Dashboard statistiques de visionnage (US-90/91).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../domain/models/watch_history_entry.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

/// Une ligne d'historique enrichie du titre affichable de l'anime.
class _HistoryRow {
  final WatchHistoryEntry entry;
  final String title;
  const _HistoryRow({required this.entry, required this.title});
}

/// Activité récente : les derniers lancements de lecture, titre résolu en local
/// (instantané, pas de réseau — repli sur l'id si le média n'est pas en cache).
final _recentHistoryProvider = FutureProvider<List<_HistoryRow>>((ref) async {
  final history = await ref.watch(watchHistoryRepositoryProvider).recent(limit: 15);
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final titleCache = <int, String>{};
  final rows = <_HistoryRow>[];
  for (final h in history) {
    var title = titleCache[h.mediaId];
    if (title == null) {
      final m = await mediaRepo.getMedia(h.mediaId);
      title = m?.title.preferred ?? m?.animeSamaTitle ?? 'ID ${h.mediaId}';
      titleCache[h.mediaId] = title;
    }
    rows.add(_HistoryRow(entry: h, title: title));
  }
  return rows;
});

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

  // Le recalcul rétroactif du progress des animes « Terminé » n'est PAS fait
  // ici : un provider de données ne doit pas déclencher d'écritures en base ni
  // de tâches de fond (fragile, et bloquerait l'affichage si anime-sama est
  // lent). Il est piloté par la page (cf. StatsPage / _maybeRecalcCompleted).

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

/// Corrige le `progress` des animes « Terminé » dont le compteur est plus bas
/// que le nombre réel d'épisodes (somme des saisons anime-sama). Piloté par la
/// page (une fois à l'ouverture), PAS par le provider de données : un provider
/// ne doit pas déclencher d'écritures/tâches de fond.
///
/// Best-effort et NON bloquant pour l'UI (lancé fire-and-forget par la page) :
/// la résolution anime-sama passe par le wrapper Python (lent, voire indispo).
/// Pas de `.timeout` ici (créerait un Timer pendant en test) : on laisse le
/// Future se résoudre/échouer naturellement. Si au moins une entrée a été
/// corrigée, on invalide `_statsDataProvider` pour réafficher les stats à jour.
Future<void> _recalcCompletedProgress(Ref ref) async {
  final listRepo = ref.read(listRepositoryProvider);
  final mediaRepo = ref.read(mediaRepositoryProvider);
  final completed = await listRepo.entriesByStatus(ListStatus.completed);
  var changed = false;
  for (final e in completed) {
    final media = await mediaRepo.getMedia(e.mediaId);
    if (media == null) continue;
    final title = media.animeSamaTitle ?? media.title.preferred;
    try {
      final total = await ref.read(animeSamaTotalEpisodesProvider(title).future);
      if (total > 0 && total > e.progress) {
        await listRepo.upsertEntry(e.copyWith(progress: total));
        changed = true;
      }
    } catch (_) {/* anime-sama indispo : on garde la valeur existante */}
  }
  if (changed) ref.invalidate(_statsDataProvider);
}

/// Provider déclencheur (autoDispose) : lu une fois par la page pour lancer le
/// recalcul rétroactif. Isolé pour que sa tâche de fond ne bloque jamais
/// `_statsDataProvider` (l'affichage).
final _recalcTriggerProvider = FutureProvider.autoDispose<void>((ref) async {
  await _recalcCompletedProgress(ref);
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
    // Déclenche (une fois, tant que la page est montée) le recalcul rétroactif
    // du progress des animes « Terminé ». Provider autoDispose isolé : sa tâche
    // de fond (résolution anime-sama, lente) ne bloque jamais l'affichage des
    // stats ci-dessous. On ne lit pas sa valeur (fire-and-forget côté UI).
    ref.watch(_recalcTriggerProvider);

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

class _StatsBody extends ConsumerWidget {
  final _StatsData data;
  const _StatsBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortedGenres = data.minutesByGenre.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(10).toList();
    final maxGenreMinutes = topGenres.isEmpty ? 1 : topGenres.first.value;
    final historyAsync = ref.watch(_recentHistoryProvider);

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

        // --- Activité récente (historique des lancements) ---
        const SizedBox(height: 20),
        Text(
          'Activité récente',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (rows) {
            if (rows.isEmpty) {
              return Text(
                'Aucune lecture récente.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: [
                for (final r in rows) _HistoryTile(row: r),
              ],
            );
          },
        ),
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

// ---------------------------------------------------------------------------
// Ligne d'activité récente (historique de lancement)
// ---------------------------------------------------------------------------

class _HistoryTile extends StatelessWidget {
  final _HistoryRow row;
  const _HistoryTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ep = row.entry.episodeNumber;
    // Affiche l'épisode sans « .0 » superflu.
    final epLabel = ep == ep.roundToDouble()
        ? 'Épisode ${ep.toInt()}'
        : 'Épisode $ep';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.play_circle_outline,
          color: theme.colorScheme.primary, size: 20),
      title: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(epLabel, style: theme.textTheme.bodySmall),
      trailing: Text(
        _relativeDate(row.entry.startedAt),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// Date relative lisible : « à l'instant », « il y a Xh », « hier », sinon
  /// jj/mm. On ne dépend PAS d'une locale externe (calcul manuel simple).
  static String _relativeDate(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    final d = when.day.toString().padLeft(2, '0');
    final m = when.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}
