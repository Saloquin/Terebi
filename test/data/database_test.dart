/// Tests de base de la TerebiDatabase (create, insert, select).
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';

void main() {
  late TerebiDatabase db;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('TerebiDatabase', () {
    test('ouvre et crée le schéma sans erreur', () async {
      // Une requête simple suffit à déclencher onCreate.
      final count = await db.select(db.mediaTable).get();
      expect(count, isEmpty);
    });

    test('insert + select MediaTable round-trip basique', () async {
      await db.into(db.mediaTable).insert(
            MediaTableCompanion(
              anilistId: const Value(1),
              titleRomaji: const Value('Shingeki no Kyojin'),
            ),
          );

      final rows = await db.select(db.mediaTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.anilistId, 1);
      expect(rows.first.titleRomaji, 'Shingeki no Kyojin');
    });

    test('insert + select ListEntries round-trip basique', () async {
      final now = DateTime.utc(2024, 1, 1);
      await db.into(db.listEntries).insert(
            ListEntriesCompanion.insert(
              mediaId: const Value(42),
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.listEntries).get();
      expect(rows, hasLength(1));
      expect(rows.first.mediaId, 42);
      expect(rows.first.status, 'planning');
    });

    test('insert + select MetaCache round-trip basique', () async {
      final exp = DateTime.utc(2025, 12, 31);
      await db.into(db.metaCache).insert(
            MetaCacheCompanion.insert(
              cacheKey: 'key1',
              payload: '{"data": 1}',
              expiresAt: exp,
            ),
          );

      final rows = await db.select(db.metaCache).get();
      expect(rows, hasLength(1));
      expect(rows.first.cacheKey, 'key1');
      expect(rows.first.payload, '{"data": 1}');
    });
  });
}
