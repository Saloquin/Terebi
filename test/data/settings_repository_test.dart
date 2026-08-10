/// Tests du SettingsRepository — dart:test, base en mémoire.
library;

import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';

void main() {
  late TerebiDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() => db.close());

  group('SettingsRepository', () {
    test('get retourne null quand la clé est absente', () async {
      final v = await repo.get('nonexistent');
      expect(v, isNull);
    });

    test('get retourne defaultValue quand la clé est absente', () async {
      final v = await repo.get('nonexistent', defaultValue: 'ani-cli');
      expect(v, equals('ani-cli'));
    });

    test('set puis get retourne la valeur persistée', () async {
      await repo.set(SettingsKeys.mpvPath, '/usr/local/bin/mpv');
      final v = await repo.get(SettingsKeys.mpvPath);
      expect(v, equals('/usr/local/bin/mpv'));
    });

    test('set écrase la valeur existante (upsert)', () async {
      await repo.set(SettingsKeys.mpvPath, 'mpv');
      await repo.set(SettingsKeys.mpvPath, '/custom/mpv');
      final v = await repo.get(SettingsKeys.mpvPath);
      expect(v, equals('/custom/mpv'));
    });

    test('delete supprime la clé (get retourne null après)', () async {
      await repo.set(SettingsKeys.mpvPath, 'mpv');
      await repo.delete(SettingsKeys.mpvPath);
      final v = await repo.get(SettingsKeys.mpvPath);
      expect(v, isNull);
    });

    test('plusieurs clés coexistent sans interférence', () async {
      await repo.set(SettingsKeys.playbackLanguage, 'vf');
      await repo.set(SettingsKeys.mpvPath, 'mpv');

      expect(await repo.get(SettingsKeys.playbackLanguage), equals('vf'));
      expect(await repo.get(SettingsKeys.mpvPath), equals('mpv'));
    });
  });
}
