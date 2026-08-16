import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/stats_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';

void main() {
  const svc = StatsService();

  // Série : episodes > 1 (ou null)
  Media tv(int id, {int? episodes, List<String> genres = const []}) =>
      Media(
        mediaId: id,
        title: MediaTitle(romaji: 'M$id'),
        episodes: episodes,
        genres: genres,
      );

  // Film : episodes == 1  → episodeMinutes retourne kDefaultMovieMinutes (120)
  Media movie(int id) => Media(
        mediaId: id,
        title: MediaTitle(romaji: 'F$id'),
        episodes: 1,
      );

  ListEntry entry(int id,
          {int progress = 0, ListStatus status = ListStatus.current}) =>
      ListEntry(
          mediaId: id, status: status, progress: progress,
          updatedAt: DateTime.utc(2020));

  group('episodeMinutes', () {
    test('défaut 24 min pour série (episodes != 1)', () {
      expect(svc.episodeMinutes(tv(1)), kDefaultEpisodeMinutes);
    });
    test('défaut 24 min pour série avec épisodes connus > 1', () {
      expect(svc.episodeMinutes(tv(1, episodes: 12)), kDefaultEpisodeMinutes);
    });
    test('défaut 120 min pour film (episodes == 1)', () {
      expect(svc.episodeMinutes(movie(1)), kDefaultMovieMinutes);
    });
  });

  group('watchedMinutes', () {
    test('série : progress × durée', () {
      expect(
          svc.watchedMinutes(media: tv(1, episodes: 12), entry: entry(1, progress: 5)),
          5 * kDefaultEpisodeMinutes);
    });
    test('film complété : durée entière (120 min) ; non vu : 0', () {
      expect(
          svc.watchedMinutes(
              media: movie(1), entry: entry(1, status: ListStatus.completed)),
          kDefaultMovieMinutes);
      expect(
          svc.watchedMinutes(
              media: movie(1), entry: entry(1, status: ListStatus.planning)),
          0);
    });
    test('série TERMINÉE sans progress incrémenté : compte tous les épisodes', () {
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: 12),
          entry: entry(1, progress: 0, status: ListStatus.completed),
        ),
        12 * kDefaultEpisodeMinutes,
      );
    });
    test('série TERMINÉE, total inconnu : retombe sur progress', () {
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: null),
          entry: entry(1, progress: 7, status: ListStatus.completed),
        ),
        7 * kDefaultEpisodeMinutes,
      );
    });
    test('série TERMINÉE : ne sous-compte jamais (max progress/total)', () {
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: 12),
          entry: entry(1, progress: 20, status: ListStatus.completed),
        ),
        20 * kDefaultEpisodeMinutes,
      );
    });
    test('série EN COURS : reste sur progress même avec total connu', () {
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: 12),
          entry: entry(1, progress: 3, status: ListStatus.current),
        ),
        3 * kDefaultEpisodeMinutes,
      );
    });
  });

  group('remainingMinutes', () {
    test('série : épisodes restants × durée', () {
      expect(
          svc.remainingMinutes(
              media: tv(1, episodes: 12), entry: entry(1, progress: 10)),
          2 * kDefaultEpisodeMinutes);
    });
    test('null si épisodes inconnus', () {
      expect(
          svc.remainingMinutes(
              media: tv(1, episodes: null), entry: entry(1, progress: 3)),
          isNull);
    });
    test('0 si déjà tout vu', () {
      expect(
          svc.remainingMinutes(
              media: tv(1, episodes: 12), entry: entry(1, progress: 12)),
          0);
    });
  });

  group('agrégats bibliothèque', () {
    final mediaById = {
      1: tv(1, episodes: 12, genres: ['Action']),
      2: movie(2),
      3: tv(3, episodes: 24, genres: ['Action', 'Comedy']),
    };
    final entries = [
      entry(1, progress: 12, status: ListStatus.completed),
      entry(2, status: ListStatus.completed),
      entry(3, progress: 10, status: ListStatus.current),
    ];

    test('totalWatchedMinutes somme correctement', () {
      // 12*24 + 120 + 10*24 = 288 + 120 + 240 = 648
      expect(
          svc.totalWatchedMinutes(entries: entries, mediaById: mediaById),
          12 * 24 + 120 + 10 * 24);
    });

    test('countByStatus', () {
      final c = svc.countByStatus(entries);
      expect(c[ListStatus.completed], 2);
      expect(c[ListStatus.current], 1);
    });

    test('watchedMinutesByGenre', () {
      final g = svc.watchedMinutesByGenre(entries: entries, mediaById: mediaById);
      // Action : media1 (12*24=288) + media3 (10*24=240) = 528
      // Comedy : media3 (240)
      expect(g['Action'], 528);
      expect(g['Comedy'], 240);
    });

    test('ignore les entrées sans média connu', () {
      final e = [...entries, entry(999, progress: 5)];
      expect(svc.totalWatchedMinutes(entries: e, mediaById: mediaById),
          12 * 24 + 120 + 10 * 24);
    });
  });
}
