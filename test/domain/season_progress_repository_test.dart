/// Tests du SeasonProgressRepository (progression par saison anime-sama).
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/season_progress_repository.dart';

void main() {
  late TerebiDatabase db;
  late SeasonProgressRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = SeasonProgressRepository(SettingsRepository(db));
  });

  tearDown(() async => db.close());

  group('SeasonProgressRepository', () {
    test('lastWatched vaut 0 par défaut', () async {
      expect(await repo.lastWatched(1, 1), 0);
    });

    test('setLastWatched + lastWatched round-trip par (média, saison)', () async {
      await repo.setLastWatched(42, 2, 5);
      expect(await repo.lastWatched(42, 2), 5);
      // Une autre saison du même média reste indépendante.
      expect(await repo.lastWatched(42, 1), 0);
      // Un autre média reste indépendant.
      expect(await repo.lastWatched(7, 2), 0);
    });

    test('setLastWatched borne les valeurs négatives à 0', () async {
      await repo.setLastWatched(1, 1, -3);
      expect(await repo.lastWatched(1, 1), 0);
    });

    test('markWatched n\'abaisse jamais le compteur', () async {
      await repo.setLastWatched(1, 1, 8);
      await repo.markWatched(1, 1, 5); // inférieur → ignoré
      expect(await repo.lastWatched(1, 1), 8);
      await repo.markWatched(1, 1, 10); // supérieur → applique
      expect(await repo.lastWatched(1, 1), 10);
    });
  });
}
