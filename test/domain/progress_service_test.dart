import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/progress_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/anime_format.dart';

void main() {
  const svc = ProgressService();
  final now = DateTime.utc(2024, 6, 1, 12);

  Media tv({int? episodes}) => Media(
        anilistId: 1,
        title: const MediaTitle(romaji: 'Série'),
        format: AnimeFormat.tv,
        episodes: episodes,
      );

  Media movie() => Media(
        anilistId: 2,
        title: const MediaTitle(romaji: 'Film'),
        format: AnimeFormat.movie,
        episodes: 1,
      );

  ListEntry entry({int progress = 0, ListStatus status = ListStatus.current}) =>
      ListEntry(mediaId: 1, status: status, progress: progress, updatedAt: DateTime.utc(2020));

  group('markCurrentWatchedAndAdvance — règle « épisode suivant »', () {
    test('épisode intermédiaire : avance et incrémente progress', () {
      final r = svc.markCurrentWatchedAndAdvance(
        entry: entry(progress: 2), media: tv(episodes: 12), currentEpisode: 3, now: now);
      expect(r.nextEpisode, 4);
      expect(r.updatedEntry.progress, 3);
      expect(r.updatedEntry.status, ListStatus.current);
      expect(r.justCompleted, isFalse);
      expect(r.updatedEntry.updatedAt, now);
    });

    test('dernier épisode : pas de suivant, passe COMPLETED', () {
      final r = svc.markCurrentWatchedAndAdvance(
        entry: entry(progress: 11), media: tv(episodes: 12), currentEpisode: 12, now: now);
      expect(r.nextEpisode, isNull);
      expect(r.updatedEntry.progress, 12);
      expect(r.updatedEntry.status, ListStatus.completed);
      expect(r.justCompleted, isTrue);
    });

    test('ne régresse pas progress si currentEpisode plus petit', () {
      final r = svc.markCurrentWatchedAndAdvance(
        entry: entry(progress: 8), media: tv(episodes: 12), currentEpisode: 3, now: now);
      expect(r.updatedEntry.progress, 8); // conservé
      expect(r.nextEpisode, 4);
    });

    test('nombre d\'épisodes inconnu : suppose un suivant', () {
      final r = svc.markCurrentWatchedAndAdvance(
        entry: entry(progress: 4), media: tv(episodes: null), currentEpisode: 5, now: now);
      expect(r.nextEpisode, 6);
      expect(r.updatedEntry.status, ListStatus.current);
      expect(r.justCompleted, isFalse);
    });

    test('film : pas de suivant, complété immédiatement', () {
      final r = svc.markCurrentWatchedAndAdvance(
        entry: entry(progress: 0), media: movie(), currentEpisode: 1, now: now);
      expect(r.nextEpisode, isNull);
      expect(r.updatedEntry.status, ListStatus.completed);
      expect(r.justCompleted, isTrue);
    });

    test('justCompleted faux si déjà COMPLETED', () {
      final r = svc.markCurrentWatchedAndAdvance(
        entry: entry(progress: 12, status: ListStatus.completed),
        media: tv(episodes: 12), currentEpisode: 12, now: now);
      expect(r.justCompleted, isFalse);
    });
  });

  group('resumeEpisode — « Reprendre »', () {
    test('reprend au prochain non vu', () {
      expect(svc.resumeEpisode(entry: entry(progress: 6), media: tv(episodes: 12)), 7);
    });

    test('null si tout vu (série)', () {
      expect(svc.resumeEpisode(entry: entry(progress: 12), media: tv(episodes: 12)), isNull);
    });

    test('épisodes inconnus : propose progress+1', () {
      expect(svc.resumeEpisode(entry: entry(progress: 3), media: tv(episodes: null)), 4);
    });

    test('film non vu : épisode 1 ; film vu : null', () {
      expect(svc.resumeEpisode(entry: entry(progress: 0), media: movie()), 1);
      expect(
        svc.resumeEpisode(
            entry: entry(progress: 1, status: ListStatus.completed), media: movie()),
        isNull,
      );
    });

    test('jamais commencé : reprend à l\'épisode 1', () {
      expect(svc.resumeEpisode(entry: entry(progress: 0), media: tv(episodes: 12)), 1);
    });
  });
}
