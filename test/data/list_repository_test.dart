/// Tests du ListRepository.
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/list_repository.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

ListEntry _entry({
  int mediaId = 1,
  ListStatus status = ListStatus.current,
  int progress = 5,
  double? score = 8.0,
  bool favorite = false,
  String? notes,
  bool hiddenFromPlanning = false,
  int? anilistEntryId,
  DateTime? updatedAt,
  DateTime? syncedAt,
}) =>
    ListEntry(
      mediaId: mediaId,
      status: status,
      progress: progress,
      score: score,
      favorite: favorite,
      notes: notes,
      hiddenFromPlanning: hiddenFromPlanning,
      anilistEntryId: anilistEntryId,
      updatedAt: updatedAt ?? DateTime.utc(2024, 6, 1),
      syncedAt: syncedAt,
    );

void main() {
  late TerebiDatabase db;
  late ListRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = ListRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ListRepository', () {
    test('getEntry retourne null si absent', () async {
      expect(await repo.getEntry(999), isNull);
    });

    test('upsertEntry + getEntry round-trip complet', () async {
      final entry = _entry(
        mediaId: 42,
        status: ListStatus.completed,
        progress: 13,
        score: 9.5,
        favorite: true,
        notes: 'chef-d\'œuvre',
        anilistEntryId: 100,
        updatedAt: DateTime.utc(2024, 3, 15),
        syncedAt: DateTime.utc(2024, 3, 16),
      );
      await repo.upsertEntry(entry);

      final result = await repo.getEntry(42);
      expect(result, isNotNull);
      expect(result!.mediaId, 42);
      expect(result.status, ListStatus.completed);
      expect(result.progress, 13);
      expect(result.score, 9.5);
      expect(result.favorite, isTrue);
      expect(result.notes, 'chef-d\'œuvre');
      expect(result.hiddenFromPlanning, isFalse);
      expect(result.anilistEntryId, 100);
      expect(result.updatedAt.toUtc(), DateTime.utc(2024, 3, 15));
      expect(result.syncedAt?.toUtc(), DateTime.utc(2024, 3, 16));
    });

    test('upsertEntry remplace une entrée existante', () async {
      await repo.upsertEntry(_entry(progress: 3));
      await repo.upsertEntry(_entry(progress: 10));

      final result = await repo.getEntry(1);
      expect(result!.progress, 10);
    });

    test('deleteEntry retire l\'entrée (getEntry → null)', () async {
      await repo.upsertEntry(_entry(mediaId: 7));
      expect(await repo.getEntry(7), isNotNull);

      await repo.deleteEntry(7);
      expect(await repo.getEntry(7), isNull);
    });

    test('deleteEntry ne touche pas les autres entrées', () async {
      await repo.upsertEntry(_entry(mediaId: 1));
      await repo.upsertEntry(_entry(mediaId: 2));

      await repo.deleteEntry(1);
      expect(await repo.getEntry(1), isNull);
      expect(await repo.getEntry(2), isNotNull);
    });

    test('entriesByStatus filtre correctement', () async {
      await repo.upsertEntry(_entry(mediaId: 1, status: ListStatus.current));
      await repo.upsertEntry(_entry(mediaId: 2, status: ListStatus.planning));
      await repo.upsertEntry(_entry(mediaId: 3, status: ListStatus.current));

      final current = await repo.entriesByStatus(ListStatus.current);
      expect(current, hasLength(2));
      expect(current.map((e) => e.mediaId).toSet(), {1, 3});

      final planning = await repo.entriesByStatus(ListStatus.planning);
      expect(planning, hasLength(1));
      expect(planning.first.mediaId, 2);
    });

    test('countByStatus renvoie le bon décompte', () async {
      await repo.upsertEntry(_entry(mediaId: 1, status: ListStatus.current));
      await repo.upsertEntry(_entry(mediaId: 2, status: ListStatus.current));
      await repo.upsertEntry(_entry(mediaId: 3, status: ListStatus.completed));
      await repo.upsertEntry(_entry(mediaId: 4, status: ListStatus.planning));

      final counts = await repo.countByStatus();
      expect(counts[ListStatus.current], 2);
      expect(counts[ListStatus.completed], 1);
      expect(counts[ListStatus.planning], 1);
      expect(counts[ListStatus.dropped], isNull);
    });

    test('setHidden masque et démasque', () async {
      await repo.upsertEntry(_entry(mediaId: 1, hiddenFromPlanning: false));
      await repo.upsertEntry(_entry(mediaId: 2, hiddenFromPlanning: false));

      await repo.setHidden(1, hidden: true);

      final hidden = await repo.allHidden();
      expect(hidden, {1});
      expect(hidden.contains(2), isFalse);

      await repo.setHidden(1, hidden: false);
      final hiddenAfter = await repo.allHidden();
      expect(hiddenAfter, isEmpty);
    });

    test('allHidden retourne ensemble vide si aucun masqué', () async {
      await repo.upsertEntry(_entry(mediaId: 1));
      expect(await repo.allHidden(), isEmpty);
    });

    test('watchEntry emet a chaque ecriture', () async {
      final emissions = <ListEntry?>[];
      final sub = repo.watchEntry(42).listen(emissions.add);
      await repo.upsertEntry(ListEntry(
          mediaId: 42, status: ListStatus.current, updatedAt: DateTime.utc(2026)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.last?.mediaId, 42);
      expect(emissions.last?.status, ListStatus.current);
    });

    test('reindexMediaId deplace l entree de old vers new', () async {
      await repo.upsertEntry(ListEntry(
          mediaId: -111, status: ListStatus.completed, progress: 5,
          updatedAt: DateTime.utc(2026)));
      await repo.reindexMediaId(-111, 777);
      expect(await repo.getEntry(-111), isNull);
      final moved = await repo.getEntry(777);
      expect(moved, isNotNull);
      expect(moved!.progress, 5);
      expect(moved.status, ListStatus.completed);
    });
  });
}
