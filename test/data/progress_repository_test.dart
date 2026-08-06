/// Tests du ProgressRepository.
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/progress_repository.dart';
import 'package:terebi/src/domain/models/episode_progress.dart';

EpisodeProgress _progress({
  int mediaId = 1,
  double episodeNumber = 1.0,
  bool watched = false,
  double positionSeconds = 0.0,
  double? durationSeconds,
  DateTime? completedAt,
  DateTime? updatedAt,
}) =>
    EpisodeProgress(
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      watched: watched,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      completedAt: completedAt,
      updatedAt: updatedAt ?? DateTime.utc(2024, 1, 1),
    );

void main() {
  late TerebiDatabase db;
  late ProgressRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = ProgressRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProgressRepository', () {
    test('getProgress retourne null si absent', () async {
      expect(await repo.getProgress(1, 1.0), isNull);
    });

    test('upsertProgress + getProgress round-trip complet', () async {
      final p = _progress(
        mediaId: 10,
        episodeNumber: 3.0,
        watched: true,
        positionSeconds: 1234.5,
        durationSeconds: 1440.0,
        completedAt: DateTime.utc(2024, 4, 10),
        updatedAt: DateTime.utc(2024, 4, 10),
      );
      await repo.upsertProgress(p);

      final result = await repo.getProgress(10, 3.0);
      expect(result, isNotNull);
      expect(result!.mediaId, 10);
      expect(result.episodeNumber, 3.0);
      expect(result.watched, isTrue);
      expect(result.positionSeconds, 1234.5);
      expect(result.durationSeconds, 1440.0);
      expect(result.completedAt?.toUtc(), DateTime.utc(2024, 4, 10));
    });

    test('upsertProgress met à jour une progression existante', () async {
      await repo.upsertProgress(_progress(episodeNumber: 1.0, positionSeconds: 100.0));
      await repo.upsertProgress(_progress(episodeNumber: 1.0, positionSeconds: 850.0, watched: true));

      final result = await repo.getProgress(1, 1.0);
      expect(result!.positionSeconds, 850.0);
      expect(result.watched, isTrue);
    });

    test('supporte les numéros d\'épisode demi-entiers (12.5)', () async {
      await repo.upsertProgress(_progress(episodeNumber: 12.5, watched: true));

      final result = await repo.getProgress(1, 12.5);
      expect(result, isNotNull);
      expect(result!.episodeNumber, 12.5);
    });

    test('lastWatched retourne null si aucun épisode watched', () async {
      await repo.upsertProgress(_progress(episodeNumber: 1.0, watched: false));
      expect(await repo.lastWatched(1), isNull);
    });

    test('lastWatched retourne le plus grand episodeNumber watched', () async {
      await repo.upsertProgress(_progress(episodeNumber: 1.0, watched: true));
      await repo.upsertProgress(_progress(episodeNumber: 5.0, watched: true));
      await repo.upsertProgress(_progress(episodeNumber: 3.0, watched: true));
      // épisode 6 non watched — ne doit pas être retourné
      await repo.upsertProgress(_progress(episodeNumber: 6.0, watched: false));

      final last = await repo.lastWatched(1);
      expect(last, isNotNull);
      expect(last!.episodeNumber, 5.0);
    });

    test('lastWatched est isolé par mediaId', () async {
      await repo.upsertProgress(_progress(mediaId: 1, episodeNumber: 10.0, watched: true));
      await repo.upsertProgress(_progress(mediaId: 2, episodeNumber: 3.0, watched: true));

      final last1 = await repo.lastWatched(1);
      final last2 = await repo.lastWatched(2);
      expect(last1!.episodeNumber, 10.0);
      expect(last2!.episodeNumber, 3.0);
    });
  });
}
