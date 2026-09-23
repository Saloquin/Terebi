library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../widgets/anime_sama_image.dart';
import '../widgets/tv_focusable.dart';
import 'media_detail_page_tv.dart';

const _statusOrder = [
  ListStatus.current,
  ListStatus.planning,
  ListStatus.completed,
  ListStatus.repeating,
  ListStatus.paused,
  ListStatus.dropped,
];

const _statusLabels = {
  ListStatus.current: 'En cours',
  ListStatus.planning: 'Planifié',
  ListStatus.completed: 'Terminé',
  ListStatus.repeating: 'Revisionnage',
  ListStatus.paused: 'En pause',
  ListStatus.dropped: 'Abandonné',
};

// Provider local : media par mediaId, best-effort (null si absent).
final _tvLibraryMediaProvider =
    FutureProvider.family<Media?, int>((ref, mediaId) async {
  return ref.watch(mediaRepositoryProvider).getMedia(mediaId);
});

class LibraryPageTv extends ConsumerStatefulWidget {
  const LibraryPageTv({super.key});

  @override
  ConsumerState<LibraryPageTv> createState() => _LibraryPageTvState();
}

class _LibraryPageTvState extends ConsumerState<LibraryPageTv> {
  ListStatus _activeTab = ListStatus.current;

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(countByStatusProvider).asData?.value ?? {};

    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          // Barre d'onglets
          SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (final status in _statusOrder)
                    _TvLibTab(
                      label: _statusLabels[status] ?? status.name,
                      count: counts[status] ?? 0,
                      selected: _activeTab == status,
                      autofocus: status == ListStatus.current,
                      onPressed: () => setState(() => _activeTab = status),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Grille d'entrées
          Expanded(
            child: _LibraryGrid(status: _activeTab),
          ),
        ],
      ),
    );
  }
}

class _TvLibTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  const _TvLibTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.autofocus,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                width: selected ? 32.0 : 0.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  final ListStatus status;
  const _LibraryGrid({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesByStatusProvider(status));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Erreur : $e', style: const TextStyle(color: Colors.white54)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          // Message focusable : sans focusable dans une grille vide, descendre
          // ici perdrait le focus (irrécupérable). En le rendant focusable, le
          // focus reste capturable et arrowUp peut remonter vers la tab bar /
          // la navbar (remontée centralisée par TvFocusScope).
          return const Focus(
            child: Center(
              child: Text(
                'Aucun anime dans cette liste',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }
        // Tri par updatedAt desc.
        final sorted = entries.sortedBy((e) => e.updatedAt).reversed.toList();

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 16 / 9,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final entry = sorted[i];
            return _LibraryTileTv(
              entry: entry,
              autofocus: i == 0,
            );
          },
        );
      },
    );
  }
}

class _LibraryTileTv extends ConsumerWidget {
  final ListEntry entry;
  final bool autofocus;

  const _LibraryTileTv({
    required this.entry,
    required this.autofocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(_tvLibraryMediaProvider(entry.mediaId));
    final media = mediaAsync.asData?.value;
    final slug = media?.animeSamaSlug ?? '';
    final coverUrl = media?.coverUrl;
    final title = media?.animeSamaTitle ??
        media?.title.preferred ??
        'Anime #${entry.mediaId}';

    return TvFocusable(
      autofocus: autofocus,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaDetailPageTv(
              mediaId: entry.mediaId,
              displayTitle: title,
              animeSamaSlug: slug.isNotEmpty ? slug : null,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaDetailPageTv(
                mediaId: entry.mediaId,
                displayTitle: title,
                animeSamaSlug: slug.isNotEmpty ? slug : null,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image (bannière si dispo, sinon cover)
              if (slug.isNotEmpty)
                AnimeSamaImage(
                  slug: slug,
                  banner: true,
                  fallbackUrl: coverUrl,
                  fit: BoxFit.cover,
                )
              else
                Container(color: Colors.white12),
              // Gradient + titre + progression
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              // Barre de progression (best-effort, null si inconnu)
              if (entry.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: (media?.episodes != null && media!.episodes! > 0)
                        ? (entry.progress / media.episodes!).clamp(0.0, 1.0)
                        : null,
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
