import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/filter_sort_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';

void main() {
  const svc = FilterSortService();

  Media m(int id,
          {String title = 'X',
          List<String> genres = const []}) =>
      Media(
        mediaId: id,
        title: MediaTitle(romaji: title),
        genres: genres,
      );

  group('filterMedia', () {
    final list = [
      m(1, title: 'Alpha', genres: ['Action', 'Comedy']),
      m(2, title: 'Beta', genres: ['Action']),
      m(3, title: 'Gamma', genres: ['Romance']),
    ];

    test('filtre vide → tout', () {
      expect(svc.filterMedia(list, const MediaFilter()).length, 3);
    });

    test('par genre (au moins un requis - OU)', () {
      // {Action, Comedy} : Alpha (Action+Comedy) ET Beta (Action) matchent ;
      // Gamma (Romance) non.
      final r = svc.filterMedia(
          list, const MediaFilter(genres: {'Action', 'Comedy'}));
      expect(r.map((e) => e.mediaId), containsAll([1, 2]));
      expect(r.length, 2);
    });

    test('par genre unique', () {
      final r = svc.filterMedia(list, const MediaFilter(genres: {'Romance'}));
      expect(r.map((e) => e.mediaId), [3]);
    });

    test('MediaFilter.isEmpty vrai si genres vide', () {
      expect(const MediaFilter().isEmpty, isTrue);
      expect(const MediaFilter(genres: {'Action'}).isEmpty, isFalse);
    });
  });

  group('sortEntries', () {
    ListEntry e(int id, {int progress = 0, DateTime? updated}) =>
        ListEntry(
          mediaId: id,
          status: ListStatus.current,
          progress: progress,
          updatedAt: updated ?? DateTime.utc(2024, 1, 1),
        );

    test('par progression asc', () {
      final list = [e(1, progress: 5), e(2, progress: 1), e(3, progress: 12)];
      expect(svc.sortEntries(list, EntrySortField.progress).map((x) => x.mediaId),
          [2, 1, 3]);
    });

    test('par titre via titleOf', () {
      final list = [e(1), e(2), e(3)];
      final titles = {1: 'Zeta', 2: 'Alpha', 3: 'Mu'};
      final r = svc.sortEntries(list, EntrySortField.title,
          titleOf: (id) => titles[id]!);
      expect(r.map((x) => x.mediaId), [2, 3, 1]);
    });

    test('par date de mise à jour desc', () {
      final list = [
        e(1, updated: DateTime.utc(2024, 1, 1)),
        e(2, updated: DateTime.utc(2024, 6, 1)),
        e(3, updated: DateTime.utc(2024, 3, 1)),
      ];
      expect(
        svc.sortEntries(list, EntrySortField.updated, descending: true).map((x) => x.mediaId),
        [2, 3, 1],
      );
    });

    test('ne mute pas la liste d\'origine', () {
      final list = [e(1, progress: 5), e(2, progress: 1), e(3, progress: 12)];
      final original = List.of(list);
      svc.sortEntries(list, EntrySortField.progress);
      expect(list.map((x) => x.mediaId), original.map((x) => x.mediaId));
    });
  });

  group('availableGenres', () {
    test('union triée des genres', () {
      final list = [
        m(1, genres: ['Action', 'Comedy']),
        m(2, genres: ['Action', 'Romance']),
      ];
      expect(svc.availableGenres(list), ['Action', 'Comedy', 'Romance']);
    });
  });
}
