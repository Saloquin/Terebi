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

const _statusOrder = ListStatus.displayOrder;

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec filtres d'onglets
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 28, 48, 12),
            child: Row(
              children: [
                const Text(
                  'Ma Liste',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in _statusOrder)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _TvLibTab(
                              label: status.label,
                              count: counts[status] ?? 0,
                              selected: _activeTab == status,
                              autofocus: status == ListStatus.current,
                              onPressed: () => setState(() => _activeTab = status),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
    final primary = Theme.of(context).colorScheme.primary;

    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.25) : const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primary : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? primary : Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
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
    final allMediaMap = ref.watch(allMediaMapProvider).value ?? const <int, Media>{};

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Erreur : $e', style: const TextStyle(color: Colors.white54)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'Aucun anime dans cette liste',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }
        final sorted = entries.sortedBy((e) => e.updatedAt).reversed.toList();

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(48, 20, 48, 48),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 16 / 9,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final entry = sorted[i];
            final media = allMediaMap[entry.mediaId];
            return _LibraryTileTv(
              entry: entry,
              media: media,
              autofocus: i == 0,
            );
          },
        );
      },
    );
  }
}

class _LibraryTileTv extends StatelessWidget {
  final ListEntry entry;
  final Media? media;
  final bool autofocus;

  const _LibraryTileTv({
    required this.entry,
    required this.media,
    required this.autofocus,
  });

  String get _displayTitle {
    if (media?.animeSamaTitle != null && media!.animeSamaTitle!.trim().isNotEmpty) {
      return media!.animeSamaTitle!;
    }
    if (media?.title.preferred != null && media!.title.preferred.isNotEmpty) {
      return media!.title.preferred;
    }
    return media?.animeSamaSlug ?? 'Anime #${entry.mediaId}';
  }

  void _open(BuildContext context) {
    final slug = media?.animeSamaSlug;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailPageTv(
          mediaId: entry.mediaId,
          displayTitle: _displayTitle,
          animeSamaSlug: (slug != null && slug.isNotEmpty) ? slug : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slug = media?.animeSamaSlug ?? '';
    final coverUrl = media?.bannerUrl ?? media?.coverUrl;

    return TvFocusable(
      autofocus: autofocus,
      onPressed: () => _open(context),
      child: GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (slug.isNotEmpty || coverUrl != null)
                AnimeSamaImage(
                  slug: slug,
                  banner: true,
                  fallbackUrl: coverUrl,
                  fit: BoxFit.cover,
                )
              else
                Container(color: const Color(0xFF1E1E22)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    _displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ),
              if (entry.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: (media?.episodes != null && media!.episodes! > 0)
                        ? (entry.progress / media!.episodes!).clamp(0.0, 1.0)
                        : null,
                    minHeight: 3.5,
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
