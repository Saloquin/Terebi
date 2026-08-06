/// Page d'accueil : « Continue watching » + accès rapide saison courante.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../widgets/media_card.dart';
import 'media_detail_page.dart';

// ---------------------------------------------------------------------------
// Helper saison courante (DateTime.now() toléré en UI)
// ---------------------------------------------------------------------------

AnimeSeason _currentSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return AnimeSeason.winter;
  if (m <= 6) return AnimeSeason.spring;
  if (m <= 9) return AnimeSeason.summer;
  return AnimeSeason.fall;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _currentEntriesProvider =
    FutureProvider<List<ListEntry>>((ref) async {
  return ref.watch(listRepositoryProvider).entriesByStatus(ListStatus.current);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Section Continue watching ---
          Text(
            'Continuer à regarder',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const _ContinueWatchingSection(),
          const SizedBox(height: 24),

          // --- Section saison courante ---
          _SeasonShortcutSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continue watching
// ---------------------------------------------------------------------------

class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_currentEntriesProvider);

    return entriesAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text('Erreur : $err'),
      data: (entries) {
        if (entries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.play_circle_outline, size: 32, color: Colors.white38),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Aucun anime en cours.\nAjoutez-en depuis le Catalogue ou le Planning.',
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _ContinueCard(entry: entries[i]),
          ),
        );
      },
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  final ListEntry entry;
  const _ContinueCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaFuture =
        ref.watch(mediaRepositoryProvider).getMedia(entry.mediaId);
    final progressFuture =
        ref.watch(progressRepositoryProvider).lastWatched(entry.mediaId);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([mediaFuture, progressFuture]),
      builder: (context, snap) {
        final media = snap.data?[0] as Media?;
        final title = media?.title.preferred ?? 'ID ${entry.mediaId}';
        final coverUrl = media?.coverUrl;
        final nextEp = entry.progress + 1;

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailPage(anilistId: entry.mediaId),
            ),
          ),
          child: SizedBox(
            width: 280,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  // Cover
                  if (coverUrl != null)
                    Image.network(
                      coverUrl,
                      width: 70,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 70, height: 120),
                    )
                  else
                    Container(
                      width: 70,
                      height: 120,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ép. ${entry.progress} vu · suivant : $nextEp',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lancer épisode $nextEp'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: Text('Épisode $nextEp'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Accès rapide saison courante
// ---------------------------------------------------------------------------

class _SeasonShortcutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final season = _currentSeason(now);
    final year = now.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saison courante',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _QuickSeasonPreview(season: season, year: year),
      ],
    );
  }
}

class _QuickSeasonPreview extends ConsumerWidget {
  final AnimeSeason season;
  final int year;

  const _QuickSeasonPreview({required this.season, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Charge les 6 premiers animes de la saison.
    final seasonAsync = FutureProvider<List<Media>>((ref) async {
      return ref
          .watch(aniListClientProvider)
          .season(season, year, perPage: 6);
    });

    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(seasonAsync);

        return async.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final media = items[i];
                  return SizedBox(
                    width: 120,
                    child: MediaCard(
                      media: media,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MediaDetailPage(anilistId: media.anilistId),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
