import 'package:test/test.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

void main() {
  final dateFixe = DateTime.utc(2024, 1, 15, 10, 0, 0);
  final dateSynchro = DateTime.utc(2024, 1, 16, 8, 0, 0);

  group('ListEntry.fromAniList', () {
    final json = <String, dynamic>{
      'id': 999,
      'mediaId': 21,
      'status': 'CURRENT',
      'progress': 42,
      'score': 8.5,
      'updatedAt': 1705312800, // 2024-01-15T10:00:00Z en epoch secondes
    };

    test('mappe les champs principaux', () {
      final entry = ListEntry.fromAniList(json);
      expect(entry.anilistEntryId, 999);
      expect(entry.mediaId, 21);
      expect(entry.status, ListStatus.current);
      expect(entry.progress, 42);
      expect(entry.score, 8.5);
      expect(entry.updatedAt.isUtc, isTrue);
    });

    test('valeurs par défaut : progress=0, score null, favorite false', () {
      final entry = ListEntry.fromAniList({
        'mediaId': 5,
        'status': 'PLANNING',
        'updatedAt': 0,
      });
      expect(entry.progress, 0);
      expect(entry.score, isNull);
      expect(entry.favorite, isFalse);
      expect(entry.hiddenFromPlanning, isFalse);
      expect(entry.anilistEntryId, isNull);
    });

    test('status par défaut PLANNING si valeur inconnue', () {
      final entry = ListEntry.fromAniList({
        'mediaId': 5,
        'status': 'UNKNOWN_VALUE',
        'updatedAt': 0,
      });
      expect(entry.status, ListStatus.planning);
    });
  });

  group('ListEntry round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = ListEntry(
        mediaId: 21,
        status: ListStatus.current,
        progress: 42,
        score: 8.5,
        favorite: true,
        notes: 'Super série',
        hiddenFromPlanning: true,
        anilistEntryId: 999,
        updatedAt: dateFixe,
        syncedAt: dateSynchro,
      );

      final restored = ListEntry.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.status, original.status);
      expect(restored.progress, original.progress);
      expect(restored.score, original.score);
      expect(restored.favorite, original.favorite);
      expect(restored.notes, original.notes);
      expect(restored.hiddenFromPlanning, original.hiddenFromPlanning);
      expect(restored.anilistEntryId, original.anilistEntryId);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.syncedAt, original.syncedAt);
    });

    test('round-trip avec champs optionnels absents', () {
      final original = ListEntry(
        mediaId: 5,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );

      final restored = ListEntry.fromJson(original.toJson());

      expect(restored.score, isNull);
      expect(restored.notes, isNull);
      expect(restored.syncedAt, isNull);
      expect(restored.anilistEntryId, isNull);
      expect(restored.favorite, isFalse);
      expect(restored.hiddenFromPlanning, isFalse);
    });
  });
}
