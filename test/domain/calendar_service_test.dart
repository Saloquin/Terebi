import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/calendar_service.dart';
import 'package:terebi/src/domain/models/airing_schedule.dart';
import 'package:terebi/src/domain/models/enums.dart';

void main() {
  const svc = CalendarService();

  AiringSchedule sched(int mediaId, DateTime airsAtUtc, {int episode = 1}) =>
      AiringSchedule(mediaId: mediaId, episode: episode, airsAt: airsAtUtc);

  group('weeklyCalendar', () {
    // Réf : lundi 2024-06-03 12:00 UTC, mercredi 2024-06-05 20:00 UTC.
    final schedules = [
      sched(1, DateTime.utc(2024, 6, 3, 12)), // lundi
      sched(2, DateTime.utc(2024, 6, 5, 20)), // mercredi
      sched(3, DateTime.utc(2024, 6, 3, 8)),  // lundi (plus tôt)
    ];
    final now = DateTime.utc(2024, 6, 10); // tout est déjà sorti

    test('regroupe par jour local (offset 0)', () {
      final cal = svc.weeklyCalendar(
        schedules: schedules,
        localOffset: Duration.zero,
        now: now,
      );
      expect(cal[DateTime.monday]!.length, 2);
      expect(cal[DateTime.wednesday]!.length, 1);
    });

    test('trie par heure locale dans le jour', () {
      final cal = svc.weeklyCalendar(
        schedules: schedules,
        localOffset: Duration.zero,
        now: now,
      );
      // Lundi : mediaId 3 (08:00) avant mediaId 1 (12:00).
      expect(cal[DateTime.monday]!.map((s) => s.schedule.mediaId), [3, 1]);
    });

    test('offset local décale le jour (UTC dimanche 23h → lundi en +2h)', () {
      final s = [sched(9, DateTime.utc(2024, 6, 2, 23))]; // dimanche 23h UTC
      final cal = svc.weeklyCalendar(
        schedules: s,
        localOffset: const Duration(hours: 2),
        now: now,
      );
      // +2h → lundi 01:00 local
      expect(cal.containsKey(DateTime.monday), isTrue);
      expect(cal.containsKey(DateTime.sunday), isFalse);
    });

    test('hideUnreleased masque les épisodes futurs', () {
      final future = DateTime.utc(2024, 6, 5); // avant mercredi 20h
      final cal = svc.weeklyCalendar(
        schedules: schedules,
        localOffset: Duration.zero,
        now: future,
        hideUnreleased: true,
      );
      // mediaId 2 (mercredi 20h) pas encore sorti → absent
      expect(cal[DateTime.wednesday], isNull);
      expect(cal[DateTime.monday]!.length, 2);
    });

    test('hideUnreleased=false garde les futurs', () {
      final future = DateTime.utc(2024, 6, 5);
      final cal = svc.weeklyCalendar(
        schedules: schedules,
        localOffset: Duration.zero,
        now: future,
        hideUnreleased: false,
      );
      expect(cal[DateTime.wednesday]!.length, 1);
    });

    test('hideUnreleased : série EN COURS (ep>=2) reste affichée même si le '
        'prochain épisode est futur', () {
      // Un anime déjà commencé : prochain épisode = 5, diffusé plus tard.
      final ongoing = [sched(50, DateTime.utc(2024, 6, 5, 20), episode: 5)];
      final now = DateTime.utc(2024, 6, 3); // le prochain ép (mercredi) est futur
      final cal = svc.weeklyCalendar(
        schedules: ongoing,
        localOffset: Duration.zero,
        now: now,
        hideUnreleased: true,
      );
      expect(cal[DateTime.wednesday]!.length, 1,
          reason: 'la série a déjà commencé (ep 1-4 sortis) → affichée');
    });

    test('hideUnreleased : nouvelle saison (ep 1 futur) est masquée (cas Dr. Stone)', () {
      // Saison qui n'a pas encore commencé : épisode 1 à venir.
      final upcoming = [sched(60, DateTime.utc(2024, 4, 22, 16), episode: 1)];
      final weekBefore = DateTime.utc(2024, 4, 15); // une semaine avant
      final cal = svc.weeklyCalendar(
        schedules: upcoming,
        localOffset: Duration.zero,
        now: weekBefore,
        hideUnreleased: true,
      );
      expect(cal.isEmpty, isTrue, reason: 'épisode 1 pas encore sorti → masquée');

      // Sans le filtre, elle apparaît.
      final calShown = svc.weeklyCalendar(
        schedules: upcoming,
        localOffset: Duration.zero,
        now: weekBefore,
        hideUnreleased: false,
      );
      expect(calShown.isEmpty, isFalse);
    });

    test('personalOnly ne garde que les mediaIds PLANNING', () {
      final cal = svc.weeklyCalendar(
        schedules: schedules,
        localOffset: Duration.zero,
        now: now,
        personalOnly: true,
        planningMediaIds: {2},
      );
      expect(cal[DateTime.wednesday]!.length, 1);
      expect(cal[DateTime.monday], isNull);
    });
  });

  group('isPersonalEmpty', () {
    final schedules = [sched(1, DateTime.utc(2024, 6, 3))];

    test('vrai si aucun PLANNING', () {
      expect(svc.isPersonalEmpty(schedules: schedules, planningMediaIds: {}), isTrue);
    });

    test('vrai si les PLANNING ne diffusent pas cette saison', () {
      expect(svc.isPersonalEmpty(schedules: schedules, planningMediaIds: {99}), isTrue);
    });

    test('faux si un PLANNING diffuse', () {
      expect(svc.isPersonalEmpty(schedules: schedules, planningMediaIds: {1}), isFalse);
    });
  });

  group('currentSeasonFor', () {
    test('mois → saison', () {
      expect(currentSeasonFor(2024, 1), const CurrentSeason(AnimeSeason.winter, 2024));
      expect(currentSeasonFor(2024, 4), const CurrentSeason(AnimeSeason.spring, 2024));
      expect(currentSeasonFor(2024, 7), const CurrentSeason(AnimeSeason.summer, 2024));
      expect(currentSeasonFor(2024, 10), const CurrentSeason(AnimeSeason.fall, 2024));
    });

    test('décembre → hiver de l\'année suivante', () {
      expect(currentSeasonFor(2024, 12), const CurrentSeason(AnimeSeason.winter, 2025));
    });
  });
}
