import 'package:test/test.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';

void main() {
  group('MediaTitle.preferred', () {
    test('préfère anglais > romaji > natif', () {
      expect(
        const MediaTitle(romaji: 'r', english: 'e', native: 'n').preferred,
        'e',
      );
      expect(const MediaTitle(romaji: 'r', native: 'n').preferred, 'r');
      expect(const MediaTitle(native: 'n').preferred, 'n');
      expect(const MediaTitle().preferred, 'Sans titre');
    });
  });

  group('Media.fromAniList', () {
    final json = <String, dynamic>{
      'id': 21,
      'idMal': 21,
      'title': {'romaji': 'One Piece', 'english': 'One Piece', 'native': 'ワンピース'},
      'format': 'TV',
      'status': 'RELEASING',
      'episodes': null,
      'duration': 24,
      'season': 'FALL',
      'seasonYear': 1999,
      'coverImage': {'large': 'https://img/large.jpg', 'medium': 'https://img/med.jpg'},
      'bannerImage': 'https://img/banner.jpg',
      'description': 'Pirates.',
      'genres': ['Action', 'Adventure'],
      'averageScore': 88,
    };

    test('mappe les champs principaux', () {
      final m = Media.fromAniList(json);
      expect(m.anilistId, 21);
      expect(m.malId, 21);
      expect(m.title.preferred, 'One Piece');
      expect(m.format, AnimeFormat.tv);
      expect(m.status, ReleaseStatus.releasing);
      expect(m.episodes, isNull);
      expect(m.durationMinutes, 24);
      expect(m.season, AnimeSeason.fall);
      expect(m.seasonYear, 1999);
      expect(m.coverUrl, 'https://img/large.jpg');
      expect(m.genres, ['Action', 'Adventure']);
      expect(m.averageScore, 88);
      expect(m.isMovie, isFalse);
    });

    test('coverUrl retombe sur medium si large absent', () {
      final j = Map<String, dynamic>.from(json)
        ..['coverImage'] = {'medium': 'https://img/med.jpg'};
      expect(Media.fromAniList(j).coverUrl, 'https://img/med.jpg');
    });

    test('isMovie vrai pour un film', () {
      final j = Map<String, dynamic>.from(json)..['format'] = 'MOVIE';
      expect(Media.fromAniList(j).isMovie, isTrue);
    });

    test('gère les champs optionnels absents', () {
      final m = Media.fromAniList({'id': 1, 'title': {'romaji': 'X'}});
      expect(m.anilistId, 1);
      expect(m.malId, isNull);
      expect(m.format, AnimeFormat.unknown);
      expect(m.status, ReleaseStatus.unknown);
      expect(m.genres, isEmpty);
      expect(m.season, isNull);
    });
  });

  group('Media round-trip JSON (cache)', () {
    test('toJson → fromJson préserve les données', () {
      final original = Media.fromAniList({
        'id': 21,
        'idMal': 21,
        'title': {'romaji': 'One Piece', 'english': 'One Piece'},
        'format': 'TV',
        'status': 'RELEASING',
        'duration': 24,
        'season': 'FALL',
        'seasonYear': 1999,
        'coverImage': {'large': 'https://img/large.jpg'},
        'genres': ['Action'],
        'averageScore': 88,
      });

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

    test('round-trip avec season null', () {
      final m = Media.fromAniList({'id': 5, 'title': {'romaji': 'Film'}, 'format': 'MOVIE'});
      final restored = Media.fromJson(m.toJson());
      expect(restored.season, isNull);
      expect(restored.isMovie, isTrue);
    });
  });
}
