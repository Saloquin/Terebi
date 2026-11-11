import 'dart:math';

import 'package:terebi/src/domain/logic/random_entry_picker.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:test/test.dart';

ListEntry _entry(int id) => ListEntry(
      mediaId: id,
      status: ListStatus.planning,
      updatedAt: DateTime(2026),
    );

void main() {
  group('shuffledEntriesForRandomPick', () {
    test('liste vide -> retourne liste vide', () {
      expect(shuffledEntriesForRandomPick(const []), isEmpty);
    });

    test('ne modifie pas la liste d’origine et conserve tous les éléments', () {
      final original = [_entry(1), _entry(2), _entry(3)];
      final res = shuffledEntriesForRandomPick(original, random: Random(42));
      expect(original.map((e) => e.mediaId), [1, 2, 3]);
      expect(res.map((e) => e.mediaId).toSet(), {1, 2, 3});
    });

    test('évite excludeMediaId en première position si >= 2 entrées', () {
      final entries = [_entry(10), _entry(20)];
      for (var seed = 0; seed < 30; seed++) {
        final res = shuffledEntriesForRandomPick(
          entries,
          excludeMediaId: 10,
          random: Random(seed),
        );
        expect(res.first.mediaId, 20);
      }
    });

    test('1 seule entrée égale à excludeMediaId -> reste sélectionnable', () {
      final res = shuffledEntriesForRandomPick(
        [_entry(10)],
        excludeMediaId: 10,
        random: Random(0),
      );
      expect(res.single.mediaId, 10);
    });
  });
}
