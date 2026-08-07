/// Page Calendrier hebdomadaire (US-82/84) — double vue GLOBAL / PERSO.
///
/// - GLOBAL : tous les anime de la saison courante.
/// - PERSO  : uniquement les anime en statut PLANNING de la saison courante.
/// - Toggle "Masquer non sortis" activé par défaut.
/// - À l'ouverture : PERSO si non vide, sinon GLOBAL.
/// - Bouton "Ajouter en Planifié" sur chaque slot du calendrier GLOBAL.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/calendar_service.dart';
import '../../domain/models/airing_schedule.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import 'media_detail_page.dart';

// ---------------------------------------------------------------------------
// Providers locaux
// ---------------------------------------------------------------------------

/// Données brutes pour le calendrier : médias saison + plannings.
final _calendarRawProvider = FutureProvider<_CalendarRaw>((ref) async {
  final anilist = ref.watch(aniListClientProvider);
  final listRepo = ref.watch(listRepositoryProvider);
  final calService = ref.watch(calendarServiceProvider);

  final now = DateTime.now().toUtc();
  final cs = currentSeasonFor(now.year, now.month);

  // Récupère les médias de la saison courante.
  final seasonMedia = await anilist.season(cs.season, cs.year);

  // Pour chaque média, récupère le nextAiring (best-effort, en parallèle).
  final schedules = <AiringSchedule>[];
  await Future.wait(
    seasonMedia.map((m) async {
      // nextAiringEpisode déjà dans le fragment _kMediaFragment via Media :
      // on ne l'a pas stocké dans Media, donc on appelle nextAiring() ici.
      // Pour limiter les appels : on ne charge que les médias RELEASING.
      try {
        final s = await anilist.nextAiring(m.anilistId);
        if (s != null) schedules.add(s);
      } catch (_) {
        // Ignore les erreurs individuelles (média terminé, rate-limit…).
      }
    }),
  );

  // MediaIds des entrées PLANNING.
  final planningEntries =
      await listRepo.entriesByStatus(ListStatus.planning);
  final planningIds = planningEntries.map((e) => e.mediaId).toSet();

  final mediaById = {for (final m in seasonMedia) m.anilistId: m};

  final isPersoEmpty = calService.isPersonalEmpty(
    schedules: schedules,
    planningMediaIds: planningIds,
  );

  return _CalendarRaw(
    schedules: schedules,
    mediaById: mediaById,
    planningIds: planningIds,
    isPersoEmpty: isPersoEmpty,
    currentSeason: cs,
  );
});

class _CalendarRaw {
  final List<AiringSchedule> schedules;
  final Map<int, Media> mediaById;
  final Set<int> planningIds;
  final bool isPersoEmpty;
  final CurrentSeason currentSeason;

  const _CalendarRaw({
    required this.schedules,
    required this.mediaById,
    required this.planningIds,
    required this.isPersoEmpty,
    required this.currentSeason,
  });
}

// ---------------------------------------------------------------------------
// Page principale
// ---------------------------------------------------------------------------

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  // true = GLOBAL, false = PERSO
  bool _showGlobal = true;
  bool _hideUnreleased = true;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final rawAsync = ref.watch(_calendarRawProvider);

    return rawAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Impossible de charger le calendrier',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      data: (raw) {
        // Initialisation unique : PERSO si non vide.
        if (!_initialized) {
          _showGlobal = raw.isPersoEmpty;
          _initialized = true;
        }

        final calService = ref.read(calendarServiceProvider);
        final localOffset = DateTime.now().timeZoneOffset;
        final now = DateTime.now().toUtc();

        final calendar = calService.weeklyCalendar(
          schedules: raw.schedules,
          localOffset: localOffset,
          now: now,
          planningMediaIds: raw.planningIds,
          personalOnly: !_showGlobal,
          hideUnreleased: _hideUnreleased,
        );

        return Column(
          children: [
            _CalendarToolbar(
              showGlobal: _showGlobal,
              hideUnreleased: _hideUnreleased,
              currentSeason: raw.currentSeason,
              onToggleView: (v) => setState(() => _showGlobal = v),
              onToggleHideUnreleased: (v) =>
                  setState(() => _hideUnreleased = v),
            ),
            Expanded(
              child: calendar.isEmpty
                  ? _EmptyCalendar(isGlobal: _showGlobal)
                  : _CalendarBody(
                      calendar: calendar,
                      mediaById: raw.mediaById,
                      planningIds: raw.planningIds,
                      isGlobal: _showGlobal,
                      localOffset: localOffset,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Barre d'outils
// ---------------------------------------------------------------------------

const _seasonLabels = {
  'winter': 'Hiver',
  'spring': 'Printemps',
  'summer': 'Été',
  'fall': 'Automne',
};

class _CalendarToolbar extends StatelessWidget {
  final bool showGlobal;
  final bool hideUnreleased;
  final CurrentSeason currentSeason;
  final void Function(bool) onToggleView;
  final void Function(bool) onToggleHideUnreleased;

  const _CalendarToolbar({
    required this.showGlobal,
    required this.hideUnreleased,
    required this.currentSeason,
    required this.onToggleView,
    required this.onToggleHideUnreleased,
  });

  @override
  Widget build(BuildContext context) {
    final seasonLabel =
        '${_seasonLabels[currentSeason.season.name] ?? currentSeason.season.name} ${currentSeason.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(seasonLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              // Toggle global / perso
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Global')),
                  ButtonSegment(value: false, label: Text('Perso')),
                ],
                selected: {showGlobal},
                onSelectionChanged: (s) => onToggleView(s.first),
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                value: hideUnreleased,
                onChanged: onToggleHideUnreleased,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Text(
                'Masquer les épisodes pas encore sortis',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// État vide
// ---------------------------------------------------------------------------

class _EmptyCalendar extends StatelessWidget {
  final bool isGlobal;
  const _EmptyCalendar({required this.isGlobal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 56, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            isGlobal
                ? 'Aucune diffusion cette semaine pour la saison courante'
                : 'Aucun anime planifié ne diffuse cette semaine',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Corps du calendrier : colonnes par jour
// ---------------------------------------------------------------------------

const _weekdayLabels = {
  1: 'Lundi',
  2: 'Mardi',
  3: 'Mercredi',
  4: 'Jeudi',
  5: 'Vendredi',
  6: 'Samedi',
  7: 'Dimanche',
};

class _CalendarBody extends ConsumerWidget {
  final Map<int, List<CalendarSlot>> calendar;
  final Map<int, Media> mediaById;
  final Set<int> planningIds;
  final bool isGlobal;
  final Duration localOffset;

  const _CalendarBody({
    required this.calendar,
    required this.mediaById,
    required this.planningIds,
    required this.isGlobal,
    required this.localOffset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jours triés (lundi→dimanche), seulement ceux qui ont des slots.
    final days = calendar.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final weekday = days[i];
        final slots = calendar[weekday]!;
        return _DaySection(
          weekday: weekday,
          slots: slots,
          mediaById: mediaById,
          planningIds: planningIds,
          isGlobal: isGlobal,
          localOffset: localOffset,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section d'un jour
// ---------------------------------------------------------------------------

class _DaySection extends StatelessWidget {
  final int weekday;
  final List<CalendarSlot> slots;
  final Map<int, Media> mediaById;
  final Set<int> planningIds;
  final bool isGlobal;
  final Duration localOffset;

  const _DaySection({
    required this.weekday,
    required this.slots,
    required this.mediaById,
    required this.planningIds,
    required this.isGlobal,
    required this.localOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _weekdayLabels[weekday] ?? 'Jour $weekday',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        for (final slot in slots)
          _SlotCard(
            slot: slot,
            media: mediaById[slot.schedule.mediaId],
            isInPlanning: planningIds.contains(slot.schedule.mediaId),
            isGlobal: isGlobal,
            localOffset: localOffset,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carte d'un slot de diffusion
// ---------------------------------------------------------------------------

class _SlotCard extends ConsumerWidget {
  final CalendarSlot slot;
  final Media? media;
  final bool isInPlanning;
  final bool isGlobal;
  final Duration localOffset;

  const _SlotCard({
    required this.slot,
    required this.media,
    required this.isInPlanning,
    required this.isGlobal,
    required this.localOffset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localTime = slot.schedule.airsAt.toUtc().add(localOffset);
    final timeStr =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final title = media?.title.preferred ?? 'ID ${slot.schedule.mediaId}';
    final coverUrl = media?.coverUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
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
          'Ép. ${slot.schedule.episode} · $timeStr',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: isGlobal
            ? _PlanningButton(
                mediaId: slot.schedule.mediaId,
                title: title,
                isInPlanning: isInPlanning,
              )
            : null,
        onTap: media != null
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MediaDetailPage(anilistId: slot.schedule.mediaId),
                  ),
                )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bouton "Ajouter en Planifié" (calendrier global uniquement)
// ---------------------------------------------------------------------------

class _PlanningButton extends ConsumerStatefulWidget {
  final int mediaId;
  final String title;
  final bool isInPlanning;

  const _PlanningButton({
    required this.mediaId,
    required this.title,
    required this.isInPlanning,
  });

  @override
  ConsumerState<_PlanningButton> createState() => _PlanningButtonState();
}

class _PlanningButtonState extends ConsumerState<_PlanningButton> {
  late bool _inPlanning;

  @override
  void initState() {
    super.initState();
    _inPlanning = widget.isInPlanning;
  }

  Future<void> _toggle() async {
    final repo = ref.read(listRepositoryProvider);
    if (_inPlanning) return; // On ne retire pas depuis ici.

    final existing = await repo.getEntry(widget.mediaId);
    final entry = existing?.copyWith(
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        ) ??
        ListEntry(
          mediaId: widget.mediaId,
          status: ListStatus.planning,
          updatedAt: DateTime.now(),
        );
    await repo.upsertEntry(entry);

    if (mounted) {
      setState(() => _inPlanning = true);
      // Invalide le provider pour que le calendrier se rafraîchisse.
      ref.invalidate(_calendarRawProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${widget.title} » ajouté en Planifié')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inPlanning) {
      return const Tooltip(
        message: 'Déjà planifié',
        child: Icon(Icons.bookmark, color: Colors.orange),
      );
    }
    return IconButton(
      icon: const Icon(Icons.bookmark_add_outlined),
      tooltip: 'Ajouter en Planifié',
      onPressed: _toggle,
    );
  }
}
