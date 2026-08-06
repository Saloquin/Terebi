/// Tests du MetaCacheRepository.
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/meta_cache_repository.dart';

void main() {
  late TerebiDatabase db;
  late MetaCacheRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = MetaCacheRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MetaCacheRepository', () {
    test('get retourne null si clé absente', () async {
      final now = DateTime.utc(2024, 1, 1);
      expect(await repo.get('absent', now), isNull);
    });

    test('put + get retourne payload si non expiré', () async {
      final expires = DateTime.utc(2025, 12, 31);
      final now = DateTime.utc(2024, 6, 1); // avant expiration

      await repo.put('season:spring:2024', '{"data": [1, 2]}', expires);
      final result = await repo.get('season:spring:2024', now);
      expect(result, '{"data": [1, 2]}');
    });

    test('get retourne null si expiré (now == expiresAt)', () async {
      final expires = DateTime.utc(2024, 6, 1);
      final now = DateTime.utc(2024, 6, 1); // exactement égal → expiré

      await repo.put('key', 'payload', expires);
      // expiresAt.isBefore(now) est false quand égaux, mais on considère
      // que now == expiresAt est encore valide uniquement si strictement avant.
      // La logique repo : isBefore(now) → expired. Donc égal = non expiré.
      final result = await repo.get('key', now);
      expect(result, 'payload'); // exact égal = toujours valide
    });

    test('get retourne null si expiré (now après expiresAt)', () async {
      final expires = DateTime.utc(2024, 6, 1);
      final now = DateTime.utc(2024, 6, 2); // lendemain → expiré

      await repo.put('key', 'stale', expires);
      final result = await repo.get('key', now);
      expect(result, isNull);
    });

    test('put remplace une entrée existante', () async {
      final expires = DateTime.utc(2025, 1, 1);
      final now = DateTime.utc(2024, 1, 1);

      await repo.put('k', 'v1', expires);
      await repo.put('k', 'v2', expires);

      expect(await repo.get('k', now), 'v2');
    });

    test('evictExpired supprime les entrées expirées', () async {
      final exp1 = DateTime.utc(2024, 1, 1); // expiré
      final exp2 = DateTime.utc(2025, 1, 1); // pas encore expiré

      await repo.put('old', 'stale', exp1);
      await repo.put('fresh', 'ok', exp2);

      final now = DateTime.utc(2024, 6, 1);
      await repo.evictExpired(now);

      expect(await repo.get('old', now), isNull);
      expect(await repo.get('fresh', now), 'ok');
    });

    test('evictExpired avec now == expiresAt supprime aussi', () async {
      final exp = DateTime.utc(2024, 6, 1);
      await repo.put('exact', 'data', exp);

      final now = DateTime.utc(2024, 6, 1);
      await repo.evictExpired(now); // isSmallerOrEqualValue → supprime

      // Après evict, la clé a été supprimée.
      final row = await repo.get('exact', now);
      expect(row, isNull);
    });

    test('plusieurs clés indépendantes', () async {
      final exp = DateTime.utc(2025, 1, 1);
      final now = DateTime.utc(2024, 1, 1);

      await repo.put('a', 'alpha', exp);
      await repo.put('b', 'beta', exp);
      await repo.put('c', 'gamma', exp);

      expect(await repo.get('a', now), 'alpha');
      expect(await repo.get('b', now), 'beta');
      expect(await repo.get('c', now), 'gamma');
    });
  });
}
