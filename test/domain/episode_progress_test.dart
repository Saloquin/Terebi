import 'package:test/test.dart';
import 'package:terebi/src/domain/models/episode_progress.dart';

void main() {
  final dateFixe = DateTime.utc(2024, 1, 15, 10, 0, 0);
  final dateComplete = DateTime.utc(2024, 1, 15, 10, 24, 0);

  group('EpisodeProgress.progressRatio', () {
    test('retourne le ratio correct', () {
      final ep = EpisodeProgress(
        mediaId: 21,
        episodeNumber: 1,
        positionSeconds: 600,
        durationSeconds: 1440,
        updatedAt: dateFixe,
      );
      expect(ep.progressRatio, closeTo(600 / 1440, 0.0001));
    });

    test('retourne 0 si durationSeconds est null', () {
      final ep = EpisodeProgress(
        mediaId: 21,
        episodeNumber: 1,
        positionSeconds: 300,
        updatedAt: dateFixe,
      );
      expect(ep.progressRatio, 0.0);
    });

    test('retourne 0 si durationSeconds est 0', () {
      final ep = EpisodeProgress(
        mediaId: 21,
        episodeNumber: 1,
        positionSeconds: 300,
        durationSeconds: 0,
        updatedAt: dateFixe,
      );
      expect(ep.progressRatio, 0.0);
    });

    test('borné à 1.0 si position dépasse la durée', () {
      final ep = EpisodeProgress(
        mediaId: 21,
        episodeNumber: 1,
        positionSeconds: 1500,
        durationSeconds: 1440,
        updatedAt: dateFixe,
      );
      expect(ep.progressRatio, 1.0);
    });

    test('supporte les numéros d\'épisodes demi (12.5)', () {
      final ep = EpisodeProgress(
        mediaId: 21,
        episodeNumber: 12.5,
        updatedAt: dateFixe,
      );
      expect(ep.episodeNumber, 12.5);
    });
  });

  group('EpisodeProgress round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = EpisodeProgress(
        mediaId: 21,
        episodeNumber: 5.0,
        watched: true,
        positionSeconds: 720,
        durationSeconds: 1440,
        completedAt: dateComplete,
        updatedAt: dateFixe,
      );

      final restored = EpisodeProgress.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.episodeNumber, original.episodeNumber);
      expect(restored.watched, original.watched);
      expect(restored.positionSeconds, original.positionSeconds);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.completedAt, original.completedAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('round-trip avec champs optionnels absents', () {
      final original = EpisodeProgress(
        mediaId: 5,
        episodeNumber: 1.0,
        updatedAt: dateFixe,
      );

      final restored = EpisodeProgress.fromJson(original.toJson());

      expect(restored.watched, isFalse);
      expect(restored.positionSeconds, 0.0);
      expect(restored.durationSeconds, isNull);
      expect(restored.completedAt, isNull);
    });
  });
}
