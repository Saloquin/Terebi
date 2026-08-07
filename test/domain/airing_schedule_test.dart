import 'package:test/test.dart';
import 'package:terebi/src/domain/models/airing_schedule.dart';

void main() {
  // 2024-01-15 10:00:00 UTC → epoch = 1705312800
  final dateDiffusion = DateTime.utc(2024, 1, 15, 10, 0, 0);

  group('AiringSchedule.fromAniList', () {
    test('mappe airingAt epoch secondes → DateTime UTC', () {
      final schedule = AiringSchedule.fromAniList(
        {'airingAt': 1705312800, 'episode': 5},
        mediaId: 21,
      );
      expect(schedule.mediaId, 21);
      expect(schedule.episode, 5);
      expect(schedule.airsAt, dateDiffusion);
      expect(schedule.airsAt.isUtc, isTrue);
      expect(schedule.notified, isFalse);
    });
  });

  group('AiringSchedule.hasAired', () {
    final schedule = AiringSchedule(
      mediaId: 21,
      episode: 5,
      airsAt: dateDiffusion,
    );

    test('retourne true si now est après airsAt', () {
      final apres = DateTime.utc(2024, 1, 15, 11, 0, 0);
      expect(schedule.hasAired(apres), isTrue);
    });

    test('retourne true si now est exactement airsAt', () {
      expect(schedule.hasAired(dateDiffusion), isTrue);
    });

    test('retourne false si now est avant airsAt', () {
      final avant = DateTime.utc(2024, 1, 15, 9, 0, 0);
      expect(schedule.hasAired(avant), isFalse);
    });
  });

  group('AiringSchedule.hasSeriesStarted', () {
    final avant = DateTime.utc(2024, 1, 15, 9);
    final apres = DateTime.utc(2024, 1, 15, 11);

    test('série en cours (prochain ép >= 2) : commencée même si ép futur', () {
      final s = AiringSchedule(mediaId: 1, episode: 5, airsAt: dateDiffusion);
      expect(s.hasSeriesStarted(avant), isTrue);
    });

    test('nouvelle saison (ép 1) pas encore diffusé : pas commencée', () {
      final s = AiringSchedule(mediaId: 1, episode: 1, airsAt: dateDiffusion);
      expect(s.hasSeriesStarted(avant), isFalse);
    });

    test('nouvelle saison (ép 1) déjà diffusé : commencée', () {
      final s = AiringSchedule(mediaId: 1, episode: 1, airsAt: dateDiffusion);
      expect(s.hasSeriesStarted(apres), isTrue);
    });
  });

  group('AiringSchedule round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = AiringSchedule(
        mediaId: 21,
        episode: 5,
        airsAt: dateDiffusion,
        notified: true,
      );

      final restored = AiringSchedule.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.episode, original.episode);
      expect(restored.airsAt, original.airsAt);
      expect(restored.notified, original.notified);
    });

    test('round-trip avec notified false par défaut', () {
      final original = AiringSchedule(
        mediaId: 5,
        episode: 1,
        airsAt: dateDiffusion,
      );

      final restored = AiringSchedule.fromJson(original.toJson());
      expect(restored.notified, isFalse);
    });
  });
}
