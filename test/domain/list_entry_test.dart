import 'package:test/test.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

void main() {
  final dateFixe = DateTime.utc(2024, 1, 15, 10, 0, 0);

  group('ListEntry round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = ListEntry(
        mediaId: 21,
        status: ListStatus.current,
        progress: 42,
        hiddenFromPlanning: true,
        updatedAt: dateFixe,
      );

      final restored = ListEntry.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.status, original.status);
      expect(restored.progress, original.progress);
      expect(restored.hiddenFromPlanning, original.hiddenFromPlanning);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('round-trip avec champs optionnels à leurs valeurs par défaut', () {
      final original = ListEntry(
        mediaId: 5,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );

      final restored = ListEntry.fromJson(original.toJson());

      expect(restored.progress, 0);
      expect(restored.hiddenFromPlanning, isFalse);
    });
  });

  group('ListEntry.copyWith', () {
    test('copyWith remplace les champs fournis', () {
      final base = ListEntry(
        mediaId: 1,
        status: ListStatus.planning,
        progress: 0,
        updatedAt: dateFixe,
      );

      final updated = base.copyWith(
        status: ListStatus.current,
        progress: 5,
        updatedAt: DateTime.utc(2024, 6, 1),
      );

      expect(updated.mediaId, 1); // conservé
      expect(updated.status, ListStatus.current);
      expect(updated.progress, 5);
      expect(updated.updatedAt, DateTime.utc(2024, 6, 1));
    });

    test('copyWith sans argument retourne une copie identique', () {
      final base = ListEntry(
        mediaId: 7,
        status: ListStatus.completed,
        progress: 12,
        hiddenFromPlanning: true,
        updatedAt: dateFixe,
      );

      final copy = base.copyWith();

      expect(copy.mediaId, base.mediaId);
      expect(copy.status, base.status);
      expect(copy.progress, base.progress);
      expect(copy.hiddenFromPlanning, base.hiddenFromPlanning);
      expect(copy.updatedAt, base.updatedAt);
    });

    test('copyWith hiddenFromPlanning', () {
      final base = ListEntry(
        mediaId: 3,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );
      expect(base.copyWith(hiddenFromPlanning: true).hiddenFromPlanning, isTrue);
      expect(base.copyWith(hiddenFromPlanning: false).hiddenFromPlanning, isFalse);
    });
  });

  group('ListEntry valeurs par défaut', () {
    test('progress=0, hiddenFromPlanning=false par défaut', () {
      final entry = ListEntry(
        mediaId: 10,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );
      expect(entry.progress, 0);
      expect(entry.hiddenFromPlanning, isFalse);
    });
  });
}
