/// Page d'accueil : accès rapide saison courante.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/enums.dart';
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
          // --- Section saison courante ---
          _SeasonShortcutSection(),
        ],
      ),
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
