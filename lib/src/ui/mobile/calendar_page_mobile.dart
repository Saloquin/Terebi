/// Page de planning / calendrier mobile tactile optimisée pour smartphone.
/// Remplace la vue 7-colonnes inadaptée par un sélecteur horizontal de jours
/// (aujourd'hui pré-sélectionné) et une liste verticale d'épisodes ordonnés par heure.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart';
import '../pages/media_detail_page.dart';
import '../widgets/anime_sama_image.dart';

const _days = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

int _timeRank(String time) {
  final m = RegExp(r'^(\d{1,2})h(\d{0,2})$').firstMatch(time.trim());
  if (m == null) return 1 << 20;
  final h = int.tryParse(m.group(1)!) ?? 0;
  final min = int.tryParse(m.group(2)!.isEmpty ? '0' : m.group(2)!) ?? 0;
  return h * 60 + min;
}

class CalendarPageMobile extends ConsumerStatefulWidget {
  const CalendarPageMobile({super.key});

  @override
  ConsumerState<CalendarPageMobile> createState() => _CalendarPageMobileState();
}

class _CalendarPageMobileState extends ConsumerState<CalendarPageMobile> {
  int _selectedDayIndex = 0;
  bool _onlyPersonal = false;

  @override
  void initState() {
    super.initState();
    // Sélectionne automatiquement le jour d'aujourd'hui (1=Lundi, 7=Dimanche)
    final todayWeekday = DateTime.now().weekday; // 1..7
    _selectedDayIndex = (todayWeekday - 1).clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final planningAsync = ref.watch(animeSamaPlanningProvider);
    final selectedDay = _days[_selectedDayIndex];

    return Column(
      children: [
        // --- 1. TOGGLE GLOBAL / MON PLANNING ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.public_rounded),
                label: Text('Tout le planning'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.bookmark_outline_rounded),
                label: Text('Mon planning'),
              ),
            ],
            selected: {_onlyPersonal},
            onSelectionChanged: (s) {
              setState(() => _onlyPersonal = s.first);
            },
          ),
        ),

        // --- 2. SÉLECTEUR DE JOUR HORIZONTAL (LUN → DIM) ---
        planningAsync.maybeWhen(
          data: (items) {
            // Calcule le nombre d'animes par jour
            final counts = <String, int>{};
            for (final it in items) {
              final d = it.day.trim();
              counts[d] = (counts[d] ?? 0) + 1;
            }

            return SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final day = _days[i];
                  final isSelected = _selectedDayIndex == i;
                  final count = counts[day] ?? 0;

                  return ChoiceChip(
                    label: Text('$day ($count)'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedDayIndex = i);
                    },
                  );
                },
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),

        // --- 3. LISTE DES SORTIES DU JOUR SÉLECTIONNÉ ---
        Expanded(
          child: planningAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur : $err', textAlign: TextAlign.center),
              ),
            ),
            data: (allItems) {
              final dayItems = allItems
                  .where((it) => it.day.toLowerCase() == selectedDay.toLowerCase())
                  .toList()
                ..sort((a, b) => _timeRank(a.time).compareTo(_timeRank(b.time)));

              return _DayReleasesView(
                day: selectedDay,
                items: dayItems,
                onlyPersonal: _onlyPersonal,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Vue des sorties pour un jour donné
class _DayReleasesView extends ConsumerWidget {
  final String day;
  final List<AnimeSamaPlanningItem> items;
  final bool onlyPersonal;

  const _DayReleasesView({
    required this.day,
    required this.items,
    required this.onlyPersonal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusMap = ref.watch(libraryStatusMapProvider).maybeWhen(
          data: (m) => m,
          orElse: () => const <int, ListStatus>{},
        );

    var displayItems = items;
    if (onlyPersonal) {
      displayItems = displayItems.where((it) {
        final id = animeSamaIdForSlug(it.slug);
        return statusMap.containsKey(id) &&
            statusMap[id] != ListStatus.dropped;
      }).toList();
    }

    if (displayItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_rounded, size: 56, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              onlyPersonal
                  ? 'Aucun anime suivi ne sort ce $day'
                  : 'Aucune sortie prévue ce $day',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: displayItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = displayItems[i];
        final id = animeSamaIdForSlug(it.slug);
        final inLibrary = statusMap.containsKey(id);

        return _PlanningItemCard(
          item: it,
          inLibrary: inLibrary,
        );
      },
    );
  }
}

/// Carte d'un anime dans le planning du jour
class _PlanningItemCard extends ConsumerWidget {
  final AnimeSamaPlanningItem item;
  final bool inLibrary;

  const _PlanningItemCard({
    required this.item,
    required this.inLibrary,
  });

  Future<void> _addToLibrary(BuildContext context, WidgetRef ref) async {
    final id = animeSamaIdForSlug(item.slug);
    final media = Media.fromAnimeSama(
      slug: item.slug,
      title: item.title,
    );
    await ref.read(mediaRepositoryProvider).upsertMedia(media);
    final listRepo = ref.read(listRepositoryProvider);
    await listRepo.upsertEntry(ListEntry(
      mediaId: id,
      status: ListStatus.planning,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(libraryStatusMapProvider);
    ref.invalidate(entriesByStatusProvider);
    ref.invalidate(countByStatusProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} ajouté à « À voir » !'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeStr = item.time.isNotEmpty ? item.time : 'Heure non précisée';

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaDetailPage(
                mediaId: animeSamaIdForSlug(item.slug),
                displayTitle: item.title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Miniature anime-sama
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 55,
                  height: 75,
                  child: item.slug.isNotEmpty
                      ? AnimeSamaImage(
                          slug: item.slug,
                          fit: BoxFit.cover,
                        )
                      : Container(color: colorScheme.surfaceContainerHighest),
                ),
              ),
              const SizedBox(width: 12),

              // Détails heure & titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge d'heure de diffusion
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule,
                              size: 12, color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Action : Ajouter à la liste ou badge suivi
              if (inLibrary)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 18, color: Colors.green),
                )
              else
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Ajouter à mes animes à voir',
                  onPressed: () => _addToLibrary(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
