import 'package:test/test.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';

void main() {
  group('MediaTitle.preferred', () {
    test('prefere anglais > romaji > natif', () {
      expect(
        const MediaTitle(romaji: 'r', english: 'e', native: 'n').preferred,
        'e',
      );
      expect(const MediaTitle(romaji: 'r', native: 'n').preferred, 'r');
      expect(const MediaTitle(native: 'n').preferred, 'n');
      expect(const MediaTitle().preferred, 'Sans titre');
    });
  });

  group('Media round-trip JSON (cache)', () {
    test('toJson -> fromJson preserve les donnees', () {
      final original = Media(
        anilistId: 21,
        malId: 21,
        title: const MediaTitle(romaji: 'One Piece', english: 'One Piece'),
        format: AnimeFormat.tv,
        status: ReleaseStatus.releasing,
        durationMinutes: 24,
        season: AnimeSeason.fall,
        seasonYear: 1999,
        coverUrl: 'https://img/large.jpg',
        genres: const ['Action'],
        averageScore: 88,
      );

      final restored = Media.fromJson(original.toJson());

      expect(restored.anilistId, original.anilistId);
      expect(restored.malId, original.malId);
      expect(restored.title.preferred, original.title.preferred);
      expect(restored.format, original.format);
      expect(restored.status, original.status);
      expect(restored.durationMinutes, original.durationMinutes);
      expect(restored.season, original.season);
      expect(restored.seasonYear, original.seasonYear);
      expect(restored.coverUrl, original.coverUrl);
      expect(restored.genres, original.genres);
      expect(restored.averageScore, original.averageScore);
    });

    test('round-trip avec season null et isMovie', () {
      const m = Media(
        anilistId: 5,
        title: MediaTitle(romaji: 'Film'),
        format: AnimeFormat.movie,
      );
      final restored = Media.fromJson(m.toJson());
      expect(restored.season, isNull);
      expect(restored.isMovie, isTrue);
    });

    test('parse et preserve nextAiringAt/Episode', () {
      final airing =
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true);
      final m = Media(
        anilistId: 100,
        title: const MediaTitle(romaji: 'Airing Show'),
        format: AnimeFormat.tv,
        status: ReleaseStatus.releasing,
        nextAiringAt: airing,
        nextAiringEpisode: 7,
      );
      expect(m.nextAiringEpisode, 7);
      expect(m.nextAiringAt, airing);

      final restored = Media.fromJson(m.toJson());
      expect(restored.nextAiringEpisode, 7);
      expect(restored.nextAiringAt, m.nextAiringAt);
    });

    test('nextAiring null si absent', () {
      const m = Media(anilistId: 1, title: MediaTitle(romaji: 'X'));
      expect(m.nextAiringAt, isNull);
      expect(m.nextAiringEpisode, isNull);
      expect(Media.fromJson(m.toJson()).nextAiringAt, isNull);
    });
  });

  group('Media.fromAnimeSama enrichi (identite slug)', () {
    test('id derive du slug, porte slug/synopsis/genres/cover', () {
      final m = Media.fromAnimeSama(
        slug: 'one-piece',
        title: 'One Piece',
        synopsis: 'Un pirate',
        genres: ['Action', 'Aventure'],
        coverUrl: 'https://cdn/c.jpg',
      );
      expect(m.anilistId, animeSamaIdForSlug('one-piece'));
      expect(m.anilistId, greaterThan(0));
      expect(m.animeSamaSlug, 'one-piece');
      expect(m.animeSamaTitle, 'One Piece');
      expect(m.title.preferred, 'One Piece');
      expect(m.description, 'Un pirate');
      expect(m.genres, ['Action', 'Aventure']);
      expect(m.coverUrl, 'https://cdn/c.jpg');
    });

    test('round-trip JSON conserve slug et enrichissement', () {
      final m = Media.fromAnimeSama(
          slug: 'naruto', title: 'Naruto', genres: ['Action']);
      final back = Media.fromJson(m.toJson());
      expect(back.anilistId, m.anilistId);
      expect(back.animeSamaSlug, 'naruto');
      expect(back.genres, ['Action']);
    });
  });
}
