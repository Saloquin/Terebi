/// Tests du provider `newEpisodeIdsProvider` — dart:test, base en mémoire.
///
/// Vérifie que l'ensemble réactif des ids « nouvel épisode » reflète bien les
/// clés settings `new_episode:<id>` (valeur '1'), et réagit aux écritures/
/// suppressions.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terebi/src/app/providers.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';

void main() {
  late TerebiDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = TerebiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<Set<int>> readIds() async =>
      container.read(newEpisodeIdsProvider.future);

  test('ensemble vide quand aucun drapeau', () async {
    expect(await readIds(), isEmpty);
  });

  test('retourne les ids des drapeaux actifs (valeur "1")', () async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.newEpisodeFor(42), '1');
    await repo.set(SettingsKeys.newEpisodeFor(7), '1');
    expect(await readIds(), {42, 7});
  });

  test('ignore les cles dont la valeur n\'est pas "1"', () async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.newEpisodeFor(42), '0');
    expect(await readIds(), isEmpty);
  });

  test('la suppression d\'un drapeau retire l\'id', () async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.newEpisodeFor(42), '1');

    // Écoute le stream et collecte les valeurs successives (le StreamProvider
    // ré-émet à chaque écriture AppSettings).
    final values = <Set<int>>[];
    final sub = container.listen<AsyncValue<Set<int>>>(
      newEpisodeIdsProvider,
      (_, next) {
        final v = next.asData?.value;
        if (v != null) values.add(v);
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    // Laisse la première émission arriver, puis supprime.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.delete(SettingsKeys.newEpisodeFor(42));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(values.isNotEmpty, isTrue);
    expect(values.last, isEmpty); // dernière émission = ensemble vide
  });
}
