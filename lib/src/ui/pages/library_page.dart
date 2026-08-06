/// Page Bibliothèque : entrées par statut avec badges de comptage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import 'media_detail_page.dart';

// ---------------------------------------------------------------------------
// Providers (visibles pour les tests via import)
// ---------------------------------------------------------------------------

final countByStatusProvider =
    FutureProvider<Map<ListStatus, int>>((ref) async {
  return ref.watch(listRepositoryProvider).countByStatus();
});

final entriesByStatusProvider =
    FutureProvider.family<List<ListEntry>, ListStatus>((ref, status) async {
  return ref.watch(listRepositoryProvider).entriesByStatus(status);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

const _statusOrder = [
  ListStatus.current,
  ListStatus.planning,
  ListStatus.completed,
  ListStatus.paused,
  ListStatus.dropped,
];

const _statusLabels = {
  ListStatus.current: 'En cours',
  ListStatus.planning: 'Planifié',
  ListStatus.completed: 'Terminé',
  ListStatus.paused: 'En pause',
  ListStatus.dropped: 'Abandonné',
};

/// Page de bibliothèque avec onglets par statut de liste.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusOrder.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(countByStatusProvider);

    return Column(
      children: [
        // --- Tab bar avec badges ---
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusOrder.map((status) {
            final count = countsAsync.maybeWhen(
              data: (m) => m[status] ?? 0,
              orElse: () => null,
            );
            final label = _statusLabels[status] ?? status.name;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(count: count),
                  ],
                ],
              ),
            );
          }).toList(),
        ),

        // --- Contenu des onglets ---
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _statusOrder
                .map((status) => _EntriesTab(status: status))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet pour un statut donné
// ---------------------------------------------------------------------------

class _EntriesTab extends ConsumerWidget {
  final ListStatus status;
  const _EntriesTab({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesByStatusProvider(status));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $err'),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text(
                  'Aucun anime dans « ${_statusLabels[status]} »',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: entries.length,
          itemBuilder: (context, i) => _EntryTile(entry: entries[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tuile d'une entrée
// ---------------------------------------------------------------------------

class _EntryTile extends ConsumerWidget {
  final ListEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaFuture =
        ref.watch(mediaRepositoryProvider).getMedia(entry.mediaId);

    return FutureBuilder<Media?>(
      future: mediaFuture,
      builder: (context, snap) {
        final media = snap.data;
        final title = media?.title.preferred ?? 'ID ${entry.mediaId}';
        final coverUrl = media?.coverUrl;

        return ListTile(
          leading: coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    coverUrl,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 40, height: 56),
                  ),
                )
              : const SizedBox(width: 40, height: 56),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            entry.progress > 0
                ? 'Progression : ép. ${entry.progress}'
                : 'Pas encore commencé',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: entry.score != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(entry.score!.toStringAsFixed(1)),
                  ],
                )
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaDetailPage(anilistId: entry.mediaId),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Badge de comptage
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
