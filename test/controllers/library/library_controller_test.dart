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

  group('LibraryState + setSortField logic', () {
    test('même champ → toggle sortDescending', () {
      const s = LibraryState(sortField: EntrySortField.updated, sortDescending: true);
      // Simule la logique de setSortField
      final s2 = s.sortField == EntrySortField.updated
          ? s.copyWith(sortDescending: !s.sortDescending)
          : s.copyWith(sortField: EntrySortField.updated, sortDescending: true);
      expect(s2.sortField, EntrySortField.updated);
      expect(s2.sortDescending, isFalse);
    });

    test('nouveau champ → sortDescending reset à true', () {
      const s = LibraryState(sortField: EntrySortField.updated, sortDescending: false);
      final s2 = s.sortField == EntrySortField.title
          ? s.copyWith(sortDescending: !s.sortDescending)
          : s.copyWith(sortField: EntrySortField.title, sortDescending: true);
      expect(s2.sortField, EntrySortField.title);
      expect(s2.sortDescending, isTrue);
    });
  });

  group('FilterSortService.sortEntries — champs supplémentaires', () {
    const service = FilterSortService();

    final entries = [
      ListEntry(mediaId: 1, status: ListStatus.current, progress: 5,
          updatedAt: DateTime(2024, 1, 3), hiddenFromPlanning: false),
      ListEntry(mediaId: 2, status: ListStatus.current, progress: 2,
          updatedAt: DateTime(2024, 1, 1), hiddenFromPlanning: false),
      ListEntry(mediaId: 3, status: ListStatus.current, progress: 10,
          updatedAt: DateTime(2024, 1, 2), hiddenFromPlanning: false),
    ];

    test('tri par progress décroissant → 10, 5, 2', () {
      final sorted = service.sortEntries(
        entries, EntrySortField.progress, descending: true,
      );
      expect(sorted.map((e) => e.progress).toList(), [10, 5, 2]);
    });

    test('tri par title avec titleOf → ordre alphabétique', () {
      final titles = {1: 'Bleach', 2: 'Attack on Titan', 3: 'Naruto'};
      final sorted = service.sortEntries(
        entries, EntrySortField.title,
        titleOf: (id) => titles[id] ?? '',
      );
      // Ascendant par défaut : Attack on Titan, Bleach, Naruto
      expect(sorted.map((e) => titles[e.mediaId]).toList(),
          ['Attack on Titan', 'Bleach', 'Naruto']);
    });

    test('liste vide → liste vide retournée', () {
      final sorted = service.sortEntries([], EntrySortField.updated);
      expect(sorted, isEmpty);
    });
  });
}
