import 'package:test/test.dart';
import 'package:terebi/src/controllers/player/episode_resolver.dart';

void main() {
  const resolver = EpisodeResolver();
  const sentinel = 1 << 20;
  final eps = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  group('resolveInitialEpisode', () {
    test('épisode demandé présent → retourné tel quel', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 5,
          episodes: eps,
          lastWatched: 3,
          fullyWatchedSentinel: sentinel,
        ),
        equals(5),
      );
    });

    test('épisode demandé absent, rien vu → premier épisode', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: 0,
          fullyWatchedSentinel: sentinel,
        ),
        equals(1),
      );
    });

    test('épisode demandé absent, 3 vus → épisode 4', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: 3,
          fullyWatchedSentinel: sentinel,
        ),
        equals(4),
      );
    });

    test('saison entièrement vue → premier épisode', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: sentinel,
          fullyWatchedSentinel: sentinel,
        ),
        equals(1),
      );
    });

    test('liste vide → requestedEpisode retourné', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 3,
          episodes: [],
          lastWatched: 0,
          fullyWatchedSentinel: sentinel,
        ),
        equals(3),
      );
    });

    test('tous vus sauf le dernier → épisode 12', () {
      expect(
        resolver.resolveInitialEpisode(
          requestedEpisode: 99,
          episodes: eps,
          lastWatched: 11,
          fullyWatchedSentinel: sentinel,
        ),
        equals(12),
      );
    });
  });

  group('nextEpisode', () {
    test('milieu de liste → suivant', () {
      expect(resolver.nextEpisode(eps, 5), equals(6));
    });
    test('dernier → null', () {
      expect(resolver.nextEpisode(eps, 12), isNull);
    });
    test('absent → null', () {
      expect(resolver.nextEpisode(eps, 99), isNull);
    });
  });

  group('prevEpisode', () {
    test('milieu de liste → précédent', () {
      expect(resolver.prevEpisode(eps, 5), equals(4));
    });
    test('premier → null', () {
      expect(resolver.prevEpisode(eps, 1), isNull);
    });
    test('absent → null', () {
      expect(resolver.prevEpisode(eps, 99), isNull);
    });
  });
}
