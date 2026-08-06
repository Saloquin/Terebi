import 'package:test/test.dart';
import 'package:terebi/src/domain/models/watch_history.dart';

void main() {
  final dateDebut = DateTime.utc(2024, 1, 15, 20, 0, 0);
  final dateFin = DateTime.utc(2024, 1, 15, 20, 24, 0);

  group('WatchHistory round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = WatchHistory(
        mediaId: 21,
        episodeNumber: 3.0,
        startedAt: dateDebut,
        endedAt: dateFin,
        watchedSeconds: 1440,
      );

      final restored = WatchHistory.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.episodeNumber, original.episodeNumber);
      expect(restored.startedAt, original.startedAt);
      expect(restored.endedAt, original.endedAt);
      expect(restored.watchedSeconds, original.watchedSeconds);
    });

    test('round-trip avec session en cours (endedAt null)', () {
      final original = WatchHistory(
        mediaId: 5,
        episodeNumber: 1.0,
        startedAt: dateDebut,
      );

      final restored = WatchHistory.fromJson(original.toJson());

      expect(restored.endedAt, isNull);
      expect(restored.watchedSeconds, 0.0);
    });

    test('supporte les numéros d\'épisodes demi (12.5)', () {
      final session = WatchHistory(
        mediaId: 21,
        episodeNumber: 12.5,
        startedAt: dateDebut,
      );
      expect(session.episodeNumber, 12.5);
    });

    test('watchedSeconds par défaut est 0', () {
      final session = WatchHistory(
        mediaId: 1,
        episodeNumber: 1,
        startedAt: dateDebut,
      );
      expect(session.watchedSeconds, 0.0);
    });
  });
}
