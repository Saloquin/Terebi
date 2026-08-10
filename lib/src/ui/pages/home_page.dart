/// Page d'accueil : reprise rapide + accès saison courante.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../widgets/media_card.dart';
import 'library_page.dart' show entriesByStatusProvider;
import 'media_detail_page.dart';
import 'resume_helper.dart';

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

/// Provider « Continuer à regarder » : médias en cours, triés du plus
/// récemment mis à jour au plus ancien, résolus en [Media] (cache local +
/// AniList best-effort). Ignore les entrées sans média résoluble.
final _continueWatchingProvider = FutureProvider<List<Media>>((ref) async {
  final entries = await ref.watch(entriesByStatusProvider(ListStatus.current).future);
  final sorted = [...entries]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  for (final e in sorted.take(12)) {
    final m = await mediaRepo.getMedia(e.mediaId);
    if (m != null) result.add(m);
  }
  return result;
});

/// Provider saison courante (top-level → mis en cache, pas recréé à chaque
/// build). Keyé sur (saison, année).
final _seasonPreviewProvider =
    FutureProvider.family<List<Media>, ({AnimeSeason season, int year})>(
        (ref, arg) async {
  return ref.watch(aniListClientProvider).season(arg.season, arg.year, perPage: 6);
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
          // --- Reprise rapide ---
          _ContinueWatchingSection(),
          // --- Section saison courante ---
          _SeasonShortcutSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continuer à regarder
// ---------------------------------------------------------------------------

class _ContinueWatchingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_continueWatchingProvider);
    return async.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Continuer à regarder',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
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
                      onResume: () => resumePlayback(context, ref, media),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaDetailPage(
                            anilistId: media.anilistId,
                            displayTitle: media.animeSamaTitle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
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
    final async =
        ref.watch(_seasonPreviewProvider((season: season, year: year)));

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
  }
}
