import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/filter_sort_service.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';

void main() {
  const svc = FilterSortService();

  Media m(int id,
          {String title = 'X',
          List<String> genres = const [],
          int? year,
          ReleaseStatus status = ReleaseStatus.finished,
          AnimeFormat format = AnimeFormat.tv,
          int? score}) =>
      Media(
        anilistId: id,
        title: MediaTitle(romaji: title),
        genres: genres,
        seasonYear: year,
        status: status,
        format: format,
        averageScore: score,
      );

  group('filterMedia', () {
    final list = [
      m(1, title: 'Alpha', genres: ['Action', 'Comedy'], year: 2020, format: AnimeFormat.tv),
      m(2, title: 'Beta', genres: ['Action'], year: 2021, format: AnimeFormat.movie),
      m(3, title: 'Gamma', genres: ['Romance'], year: 2020, status: ReleaseStatus.releasing),
    ];

    test('filtre vide → tout', () {
      expect(svc.filterMedia(list, const MediaFilter()).length, 3);
    });

    test('par genre (tous requis)', () {
      final r = svc.filterMedia(list, const MediaFilter(genres: {'Action', 'Comedy'}));
      expect(r.map((e) => e.anilistId), [1]);
    });

    test('par année', () {
      final r = svc.filterMedia(list, const MediaFilter(year: 2020));
      expect(r.map((e) => e.anilistId), [1, 3]);
    });

    test('par format', () {
      final r = svc.filterMedia(list, const MediaFilter(format: AnimeFormat.movie));
      expect(r.map((e) => e.anilistId), [2]);
    });

    test('par statut', () {
      final r = svc.filterMedia(list, const MediaFilter(status: ReleaseStatus.releasing));
      expect(r.map((e) => e.anilistId), [3]);
    });

    test('critères combinés', () {
      final r = svc.filterMedia(list, const MediaFilter(genres: {'Action'}, year: 2020));
      expect(r.map((e) => e.anilistId), [1]);
    });
  });

  group('sortMedia', () {
    final list = [
      m(1, title: 'Charlie', year: 2019, score: 70),
      m(2, title: 'alpha', year: 2022, score: 90),
      m(3, title: 'Bravo', year: 2020, score: 80),
    ];

    test('par titre (insensible à la casse)', () {
      expect(svc.sortMedia(list, MediaSortField.title).map((e) => e.anilistId),
          [2, 3, 1]);
    });

    test('par année desc', () {
      expect(
        svc.sortMedia(list, MediaSortField.year, descending: true).map((e) => e.anilistId),
        [2, 3, 1],
      );
    });

    test('par score desc', () {
      expect(
        svc.sortMedia(list, MediaSortField.score, descending: true).map((e) => e.anilistId),
        [2, 3, 1],
      );
    });

    test('ne mute pas la liste d\'origine', () {
      final original = List.of(list);
      svc.sortMedia(list, MediaSortField.title);
      expect(list.map((e) => e.anilistId), original.map((e) => e.anilistId));
    });
  });

  group('sortEntries', () {
    ListEntry e(int id, {double? score, int progress = 0, DateTime? updated}) =>
        ListEntry(
          mediaId: id,
          status: ListStatus.current,
          score: score,
          progress: progress,
          updatedAt: updated ?? DateTime.utc(2024, 1, 1),
        );

    test('par score desc', () {
      final list = [e(1, score: 6), e(2, score: 9), e(3, score: 7)];
      expect(
        svc.sortEntries(list, EntrySortField.score, descending: true).map((x) => x.mediaId),
        [2, 3, 1],
      );
    });

    test('par progression', () {
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
