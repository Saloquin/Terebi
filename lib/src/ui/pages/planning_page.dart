/// Page Planning : animes de la saison courante avec masquage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/media.dart';
import '../widgets/media_card.dart';
import 'media_detail_page.dart';

// ---------------------------------------------------------------------------
// Helpers saison courante (DateTime.now() toléré en UI)
// ---------------------------------------------------------------------------

AnimeSeason _currentSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return AnimeSeason.winter;
  if (m <= 6) return AnimeSeason.spring;
  if (m <= 9) return AnimeSeason.summer;
  return AnimeSeason.fall;
}

const _seasonLabels = {
  AnimeSeason.winter: 'Hiver',
  AnimeSeason.spring: 'Printemps',
  AnimeSeason.summer: 'Été',
  AnimeSeason.fall: 'Automne',
};

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Clé de requête saison : (saison, année).
typedef _SeasonKey = ({AnimeSeason season, int year});

final _seasonMediaProvider =
    FutureProvider.family<List<Media>, _SeasonKey>((ref, key) async {
  return ref.watch(aniListClientProvider).season(key.season, key.year);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key});

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  late AnimeSeason _season;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _season = _currentSeason(now);
    _year = now.year;
  }

  void _prevSeason() => setState(() {
        if (_season == AnimeSeason.winter) {
          _season = AnimeSeason.fall;
          _year--;
        } else {
          _season = AnimeSeason.values[_season.index - 1];
        }
      });

  void _nextSeason() => setState(() {
        if (_season == AnimeSeason.fall) {
          _season = AnimeSeason.winter;
          _year++;
        } else {
          _season = AnimeSeason.values[_season.index + 1];
        }
      });

  @override
  Widget build(BuildContext context) {
    final key = (season: _season, year: _year);
    final mediaAsync = ref.watch(_seasonMediaProvider(key));
    final hiddenFuture = ref.watch(
      Provider((ref) => ref.watch(listRepositoryProvider).allHidden()),
    );

    return Column(
      children: [
        // --- Sélecteur saison/année ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevSeason,
                tooltip: 'Saison précédente',
              ),
              const SizedBox(width: 8),
              Text(
                '${_seasonLabels[_season]} $_year',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextSeason,
                tooltip: 'Saison suivante',
              ),
            ],
          ),
        ),

        // --- Grille ---
        Expanded(
          child: mediaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Impossible de charger la saison',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(err.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('Aucun anime pour cette saison'),
                );
              }
              return FutureBuilder<Set<int>>(
                future: hiddenFuture,
                builder: (context, snap) {
                  final hidden = snap.data ?? const {};
                  final visible =
                      items.where((m) => !hidden.contains(m.anilistId)).toList();
                  if (visible.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Tous les animes sont masqués.'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {},
                            child: const Text('(rechargement requis pour réafficher)'),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.50,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final media = visible[i];
                      return _PlanningCard(media: media);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carte Planning (avec bouton masquer)
// ---------------------------------------------------------------------------

class _PlanningCard extends ConsumerWidget {
  final Media media;
  const _PlanningCard({required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Carte complète cliquable
        Positioned.fill(
          child: MediaCard(
            media: media,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaDetailPage(anilistId: media.anilistId),
              ),
            ),
          ),
        ),
        // Bouton masquer
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await ref
                    .read(listRepositoryProvider)
                    .setHidden(media.anilistId, hidden: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('« ${media.title.preferred} » masqué'),
                      action: SnackBarAction(
                        label: 'Annuler',
                        onPressed: () async {
                          await ref
                              .read(listRepositoryProvider)
                              .setHidden(media.anilistId, hidden: false);
                        },
                      ),
                    ),
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.visibility_off, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
