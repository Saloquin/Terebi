import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/stats_service.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';

void main() {
  const svc = StatsService();

  Media tv(int id, {int? episodes, int? duration, List<String> genres = const []}) =>
      Media(
        anilistId: id,
        title: MediaTitle(romaji: 'M$id'),
        format: AnimeFormat.tv,
        episodes: episodes,
        durationMinutes: duration,
        genres: genres,
      );

  Media movie(int id, {int? duration}) => Media(
        anilistId: id,
        title: MediaTitle(romaji: 'F$id'),
        format: AnimeFormat.movie,
        episodes: 1,
        durationMinutes: duration,
      );

  ListEntry entry(int id, {int progress = 0, ListStatus status = ListStatus.current, double? score}) =>
      ListEntry(mediaId: id, status: status, progress: progress, score: score, updatedAt: DateTime.utc(2020));

  group('episodeMinutes', () {
    test('utilise la durée réelle si connue', () {
      expect(svc.episodeMinutes(tv(1, duration: 23)), 23);
    });
    test('défaut 24 min pour série sans durée', () {
      expect(svc.episodeMinutes(tv(1)), 24);
    });
    test('défaut 120 min pour film sans durée', () {
      expect(svc.episodeMinutes(movie(1)), 120);
    });
  });

  group('watchedMinutes', () {
    test('série : progress × durée', () {
      expect(svc.watchedMinutes(media: tv(1, duration: 24), entry: entry(1, progress: 5)), 120);
    });
    test('film complété : durée entière ; non vu : 0', () {
      expect(svc.watchedMinutes(media: movie(1, duration: 90), entry: entry(1, status: ListStatus.completed)), 90);
      expect(svc.watchedMinutes(media: movie(1, duration: 90), entry: entry(1, status: ListStatus.planning)), 0);
    });
    test('série TERMINÉE sans progress incrémenté : compte tous les épisodes', () {
      // « Terminé » manuel : progress resté à 0, mais 12 épisodes connus.
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: 12, duration: 24),
          entry: entry(1, progress: 0, status: ListStatus.completed),
        ),
        12 * 24,
      );
    });
    test('série TERMINÉE, total inconnu : retombe sur progress', () {
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: null, duration: 24),
          entry: entry(1, progress: 7, status: ListStatus.completed),
        ),
        7 * 24,
      );
    });
    test('série TERMINÉE : ne sous-compte jamais (max progress/total)', () {
      // progress > episodes (données incohérentes) → on garde le plus grand.
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: 12, duration: 24),
          entry: entry(1, progress: 20, status: ListStatus.completed),
        ),
        20 * 24,
      );
    });
    test('série EN COURS : reste sur progress même avec total connu', () {
      expect(
        svc.watchedMinutes(
          media: tv(1, episodes: 12, duration: 24),
          entry: entry(1, progress: 3, status: ListStatus.current),
        ),
        3 * 24,
      );
    });
  });

  group('remainingMinutes', () {
    test('série : épisodes restants × durée', () {
      expect(svc.remainingMinutes(media: tv(1, episodes: 12, duration: 24), entry: entry(1, progress: 10)), 48);
    });
    test('null si épisodes inconnus', () {
      expect(svc.remainingMinutes(media: tv(1, episodes: null), entry: entry(1, progress: 3)), isNull);
    });
    test('0 si déjà tout vu', () {
      expect(svc.remainingMinutes(media: tv(1, episodes: 12, duration: 24), entry: entry(1, progress: 12)), 0);
    });
  });

  group('agrégats bibliothèque', () {
    final mediaById = {
      1: tv(1, episodes: 12, duration: 24, genres: ['Action']),
      2: movie(2, duration: 100),
      3: tv(3, episodes: 24, duration: 24, genres: ['Action', 'Comedy']),
    };
    final entries = [
      entry(1, progress: 12, status: ListStatus.completed),
      entry(2, status: ListStatus.completed),
      entry(3, progress: 10, status: ListStatus.current),
    ];

    test('totalWatchedMinutes somme correctement', () {
      // 12*24 + 100 + 10*24 = 288 + 100 + 240 = 628
      expect(svc.totalWatchedMinutes(entries: entries, mediaById: mediaById), 628);
    });

    test('countByStatus', () {
      final c = svc.countByStatus(entries);
      expect(c[ListStatus.completed], 2);
      expect(c[ListStatus.current], 1);
    });

    test('watchedMinutesByGenre', () {
      final g = svc.watchedMinutesByGenre(entries: entries, mediaById: mediaById);
      // Action : media1 (288) + media3 (240) = 528 ; Comedy : media3 (240)
      expect(g['Action'], 528);
      expect(g['Comedy'], 240);
    });

    test('ignore les entrées sans média connu', () {
      final e = [...entries, entry(999, progress: 5)];
      expect(svc.totalWatchedMinutes(entries: e, mediaById: mediaById), 628);
    });
  });
}
