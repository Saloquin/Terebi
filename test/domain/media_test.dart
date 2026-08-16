import 'package:test/test.dart';
import 'package:terebi/src/domain/models/media.dart';
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
        mediaId: 21,
        title: const MediaTitle(romaji: 'One Piece', english: 'One Piece'),
        episodes: 1000,
        coverUrl: 'https://img/large.jpg',
        bannerUrl: 'https://img/banner.jpg',
        description: 'Un pirate cherche un tresor',
        genres: const ['Action'],
        animeSamaTitle: 'One Piece',
        animeSamaSlug: 'one-piece',
      );

      final restored = Media.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.title.preferred, original.title.preferred);
      expect(restored.episodes, original.episodes);
      expect(restored.coverUrl, original.coverUrl);
      expect(restored.bannerUrl, original.bannerUrl);
      expect(restored.description, original.description);
      expect(restored.genres, original.genres);
      expect(restored.animeSamaTitle, original.animeSamaTitle);
      expect(restored.animeSamaSlug, original.animeSamaSlug);
    });

    test('round-trip avec champs optionnels absents', () {
      const m = Media(
        mediaId: 5,
        title: MediaTitle(romaji: 'Film'),
      );
      final restored = Media.fromJson(m.toJson());
      expect(restored.mediaId, 5);
      expect(restored.episodes, isNull);
      expect(restored.coverUrl, isNull);
      expect(restored.genres, isEmpty);
    });

    test('retro-compat : fromJson accepte ancienne cle anilistId', () {
      final json = <String, dynamic>{
        'anilistId': 42,
        'title': {'romaji': 'Old Cache', 'english': null, 'native': null},
        'episodes': null,
        'coverUrl': null,
        'bannerUrl': null,
        'description': null,
        'genres': <dynamic>[],
        'animeSamaTitle': null,
        'animeSamaSlug': null,
      };
      final m = Media.fromJson(json);
      expect(m.mediaId, 42);
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
      expect(m.mediaId, animeSamaIdForSlug('one-piece'));
      expect(m.mediaId, greaterThan(0));
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
      expect(back.mediaId, m.mediaId);
      expect(back.animeSamaSlug, 'naruto');
      expect(back.genres, ['Action']);
    });
  });

  group('Media.withId / withSlug / withAnimeSamaTitle', () {
    test('withId retourne une copie avec le nouvel id', () {
      final m = Media.fromAnimeSama(slug: 'bleach', title: 'Bleach');
      final m2 = m.withId(999);
      expect(m2.mediaId, 999);
      expect(m2.animeSamaSlug, 'bleach');
      expect(m2.title.preferred, 'Bleach');
    });

    test('withSlug retourne une copie avec le nouveau slug', () {
      const m = Media(mediaId: 1, title: MediaTitle(romaji: 'Test'));
      final m2 = m.withSlug('test-slug');
      expect(m2.animeSamaSlug, 'test-slug');
      expect(m2.mediaId, 1);
    });

    test('withAnimeSamaTitle retourne une copie avec le nouveau titre sama', () {
      const m = Media(mediaId: 1, title: MediaTitle(romaji: 'Test'));
      final m2 = m.withAnimeSamaTitle('Titre Sama');
      expect(m2.animeSamaTitle, 'Titre Sama');
      expect(m2.mediaId, 1);
    });
  });
}
