import 'package:test/test.dart';
import 'package:terebi/src/controllers/library/library_state.dart';
import 'package:terebi/src/domain/logic/filter_sort_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

void main() {
  group('LibraryState.copyWith', () {
    test('sort field change préserve les autres champs', () {
      const s = LibraryState(sortDescending: false, searchQuery: 'naruto');
      final s2 = s.copyWith(sortField: EntrySortField.title);
      expect(s2.sortField, EntrySortField.title);
      expect(s2.sortDescending, isFalse);
      expect(s2.searchQuery, 'naruto');
    });

    test('copyWith sans arguments retourne état identique', () {
      const s = LibraryState(recheckRunning: true);
      final s2 = s.copyWith();
      expect(s2.recheckRunning, isTrue);
    });
  });

  group('FilterSortService.sortEntries', () {
    const service = FilterSortService();

    final entries = [
      ListEntry(
          mediaId: 1,
          status: ListStatus.current,
          progress: 5,
          updatedAt: DateTime(2024, 1, 3),
          hiddenFromPlanning: false),
      ListEntry(
          mediaId: 2,
          status: ListStatus.current,
          progress: 2,
          updatedAt: DateTime(2024, 1, 1),
          hiddenFromPlanning: false),
      ListEntry(
          mediaId: 3,
          status: ListStatus.current,
          progress: 10,
          updatedAt: DateTime(2024, 1, 2),
          hiddenFromPlanning: false),
    ];

    test('tri par updated décroissant → mediaId 1, 3, 2', () {
      final sorted = service.sortEntries(
        entries,
        EntrySortField.updated,
        descending: true,
      );
      expect(sorted.map((e) => e.mediaId).toList(), [1, 3, 2]);
    });

    test('tri par updated croissant → mediaId 2, 3, 1', () {
      final sorted = service.sortEntries(
        entries,
        EntrySortField.updated,
        descending: false,
      );
      expect(sorted.map((e) => e.mediaId).toList(), [2, 3, 1]);
    });
  });
}
