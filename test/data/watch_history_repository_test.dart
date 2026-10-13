import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/watch_history_repository.dart';

void main() {
  late TerebiDatabase db;
  late WatchHistoryRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = WatchHistoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WatchHistoryRepository', () {
    test('record + recent + forMedia round-trip', () async {
      final now = DateTime.utc(2026, 1, 1);
      await repo.record(mediaId: 10, episodeNumber: 1.0, startedAt: now);
      await repo.record(mediaId: 20, episodeNumber: 2.0, startedAt: now.add(const Duration(minutes: 1)));

      final allRecent = await repo.recent();
      expect(allRecent.length, 2);

      final forMedia10 = await repo.forMedia(10);
      expect(forMedia10.length, 1);
      expect(forMedia10.first.mediaId, 10);
      expect(forMedia10.first.episodeNumber, 1.0);

      final forMedia30 = await repo.forMedia(30);
      expect(forMedia30, isEmpty);
    });

    test('reindexMediaId updates rows to new mediaId', () async {
      final now = DateTime.utc(2026, 1, 1);
      await repo.record(mediaId: 10, episodeNumber: 1.0, startedAt: now);

      await repo.reindexMediaId(10, 50);

      expect(await repo.forMedia(10), isEmpty);
      final for50 = await repo.forMedia(50);
      expect(for50.length, 1);
      expect(for50.first.mediaId, 50);
    });
  });
}
