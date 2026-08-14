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
      await repo.set(SettingsKeys.pythonPath, '/usr/local/bin/python');
      final v = await repo.get(SettingsKeys.pythonPath);
      expect(v, equals('/usr/local/bin/python'));
    });

    test('set écrase la valeur existante (upsert)', () async {
      await repo.set(SettingsKeys.pythonPath, 'python');
      await repo.set(SettingsKeys.pythonPath, '/custom/python');
      final v = await repo.get(SettingsKeys.pythonPath);
      expect(v, equals('/custom/python'));
    });

    test('delete supprime la clé (get retourne null après)', () async {
      await repo.set(SettingsKeys.pythonPath, 'python');
      await repo.delete(SettingsKeys.pythonPath);
      final v = await repo.get(SettingsKeys.pythonPath);
      expect(v, isNull);
    });

    test('plusieurs clés coexistent sans interférence', () async {
      await repo.set(SettingsKeys.playbackLanguage, 'vf');
      await repo.set(SettingsKeys.pythonPath, 'python');

      expect(await repo.get(SettingsKeys.playbackLanguage), equals('vf'));
      expect(await repo.get(SettingsKeys.pythonPath), equals('python'));
    });

    test('watchWithPrefix emet a chaque ecriture de cle prefixee', () async {
      final emissions = <Map<String, String>>[];
      final sub = repo.watchWithPrefix('anime_sama_watched:5:').listen(emissions.add);
      await repo.set('anime_sama_watched:5:1', '3');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.last['anime_sama_watched:5:1'], '3');
    });

    test('renameKeyPrefix renomme les cles old->new en conservant la valeur', () async {
      await repo.set('anime_sama_watched:-9:1', '4');
      await repo.set('anime_sama_watched:-9:2', '7');
      await repo.renameKeyPrefix('anime_sama_watched:-9:', 'anime_sama_watched:123:');
      expect(await repo.get('anime_sama_watched:-9:1'), isNull);
      expect(await repo.get('anime_sama_watched:123:1'), '4');
      expect(await repo.get('anime_sama_watched:123:2'), '7');
    });
  });
}
