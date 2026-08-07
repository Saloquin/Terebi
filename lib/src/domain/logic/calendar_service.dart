/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Logique du calendrier hebdomadaire de diffusion (US-82/84) :
/// - regroupe les diffusions par jour de semaine (en heure locale) ;
/// - distingue calendrier GLOBAL (toute la saison) et PERSO (médias en PLANNING) ;
/// - filtre optionnel « masquer les épisodes pas encore diffusés ».
///
/// Toutes les dépendances temporelles (now, décalage local) sont injectées pour
/// rester déterministe et testable.
library;

import '../models/airing_schedule.dart';
import '../models/enums.dart';

/// Jour de la semaine (lundi = 1, dimanche = 7 — comme `DateTime.weekday`).
typedef Weekday = int;

/// Une diffusion positionnée dans la semaine locale.
class CalendarSlot {
  final AiringSchedule schedule;

  /// Jour local de diffusion (1 = lundi … 7 = dimanche).
  final Weekday weekday;

  const CalendarSlot({required this.schedule, required this.weekday});
}

/// Logique pure du calendrier.
class CalendarService {
  const CalendarService();

  /// Construit le calendrier hebdomadaire.
  ///
  /// [schedules]      : diffusions de la saison (global).
  /// [localOffset]    : décalage du fuseau local (ex. `Duration(hours: 2)`), pour
  ///                    convertir `airsAt` (UTC) en heure locale sans dépendre de
  ///                    l'horloge système.
  /// [now]            : instant de référence (UTC) pour le filtre « pas encore sorti ».
  /// [planningMediaIds] : mediaIds en statut PLANNING → calendrier perso.
  /// [personalOnly]   : si vrai, ne garde que les diffusions perso.
  /// [hideUnreleased] : si vrai (défaut), masque les épisodes dont `airsAt` est
  ///                    dans le futur par rapport à [now].
  ///
  /// Retourne une map { weekday(1..7) → slots triés par heure locale }.
  Map<Weekday, List<CalendarSlot>> weeklyCalendar({
    required List<AiringSchedule> schedules,
    required Duration localOffset,
    required DateTime now,
    Set<int> planningMediaIds = const {},
    bool personalOnly = false,
    bool hideUnreleased = true,
  }) {
    final result = <Weekday, List<CalendarSlot>>{};

    for (final s in schedules) {
      if (personalOnly && !planningMediaIds.contains(s.mediaId)) continue;
      if (hideUnreleased && !s.hasAired(now)) continue;

      final local = s.airsAt.toUtc().add(localOffset);
      final weekday = local.weekday; // 1..7
      (result[weekday] ??= []).add(
        CalendarSlot(schedule: s, weekday: weekday),
      );
    }

    // Tri par heure locale dans chaque jour.
    for (final slots in result.values) {
      slots.sort((a, b) {
        final la = a.schedule.airsAt.add(localOffset);
        final lb = b.schedule.airsAt.add(localOffset);
        return la.compareTo(lb);
      });
    }

    return result;
  }

  /// `true` si le calendrier perso est vide (aucun média PLANNING ne diffuse
  /// cette saison) → l'UI ouvre alors le calendrier global.
  bool isPersonalEmpty({
    required List<AiringSchedule> schedules,
    required Set<int> planningMediaIds,
  }) {
    if (planningMediaIds.isEmpty) return true;
    return !schedules.any((s) => planningMediaIds.contains(s.mediaId));
  }
}

// ---------------------------------------------------------------------------
// Saison de diffusion courante
// ---------------------------------------------------------------------------

/// Saison courante (saison + année) calculée à partir d'une date.
class CurrentSeason {
  final AnimeSeason season;
  final int year;
  const CurrentSeason(this.season, this.year);

  @override
  bool operator ==(Object other) =>
      other is CurrentSeason && other.season == season && other.year == year;

  @override
  int get hashCode => Object.hash(season, year);

  @override
  String toString() => '${season.name} $year';
}

/// Calcule la saison de diffusion pour un [month] (1..12) et une [year].
/// Winter: déc–fév, Spring: mars–mai, Summer: juin–août, Fall: sept–nov.
/// (décembre est rattaché à l'hiver de l'année suivante.)
CurrentSeason currentSeasonFor(int year, int month) {
  if (month == 12) return CurrentSeason(AnimeSeason.winter, year + 1);
  if (month <= 2) return CurrentSeason(AnimeSeason.winter, year);
  if (month <= 5) return CurrentSeason(AnimeSeason.spring, year);
  if (month <= 8) return CurrentSeason(AnimeSeason.summer, year);
  return CurrentSeason(AnimeSeason.fall, year);
}
