import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/remote/jikan_client.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';

// ---------------------------------------------------------------------------
// Fixtures Jikan réalistes
// ---------------------------------------------------------------------------

Map<String, dynamic> _jikanAnime({
  int malId = 1535,
  String title = 'Death Note',
  String? titleEnglish = 'Death Note',
  String? titleJapanese = 'デスノート',
  String type = 'TV',
  String status = 'Finished Airing',
  int? episodes = 37,
  String duration = '23 min per ep',
  String? season = 'fall',
  int? year = 2006,
  String coverLarge = 'https://cdn.myanimelist.net/images/anime/9/9453l.jpg',
  String? synopsis = 'A student finds a notebook.',
  List<Map<String, dynamic>> genres = const [
    {'mal_id': 37, 'name': 'Supernatural'},
    {'mal_id': 7, 'name': 'Mystery'},
  ],
  double score = 8.6,
}) =>
    {
      'mal_id': malId,
      'title': title,
      'title_english': titleEnglish,
      'title_japanese': titleJapanese,
      'type': type,
      'status': status,
      'episodes': episodes,
      'duration': duration,
      'season': season,
      'year': year,
      'images': {
        'jpg': {
          'image_url': 'https://cdn.myanimelist.net/images/anime/9/9453.jpg',
          'large_image_url': coverLarge,
        },
      },
      'synopsis': synopsis,
      'genres': genres,
      'score': score,
    };

http.Response _ok(List<Map<String, dynamic>> data) => http.Response(
      jsonEncode({'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );

http.Response _err(int code) => http.Response('Error', code);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JikanClient.searchByTitle', () {
    test('mappe correctement un anime Jikan → Media', () async {
      final mock = MockClient((_) async => _ok([_jikanAnime()]));
      final results = await JikanClient(client: mock).searchByTitle('death note');

      expect(results, hasLength(1));
      final m = results.first;
      expect(m.malId, 1535);
      expect(m.anilistId, 1535); // Jikan n'a pas d'ID AniList → malId utilisé
      expect(m.title.romaji, 'Death Note');
      expect(m.title.english, 'Death Note');
      expect(m.title.native, 'デスノート');
      expect(m.format, AnimeFormat.tv);
      expect(m.status, ReleaseStatus.finished);
      expect(m.episodes, 37);
      expect(m.durationMinutes, 23);
      expect(m.season, AnimeSeason.fall);
      expect(m.seasonYear, 2006);
      expect(m.coverUrl, 'https://cdn.myanimelist.net/images/anime/9/9453l.jpg');
      expect(m.description, 'A student finds a notebook.');
      expect(m.genres, containsAll(['Supernatural', 'Mystery']));
      // score 8.6 → 86
      expect(m.averageScore, 86);
    });

    test('mappe le format Movie', () async {
      final mock = MockClient((_) async => _ok([_jikanAnime(type: 'Movie')]));
      final m = (await JikanClient(client: mock).searchByTitle('film')).first;
      expect(m.format, AnimeFormat.movie);
      expect(m.isMovie, isTrue);
    });

    test('mappe le format OVA', () async {
      final mock = MockClient((_) async => _ok([_jikanAnime(type: 'OVA')]));
      final m = (await JikanClient(client: mock).searchByTitle('ova')).first;
      expect(m.format, AnimeFormat.ova);
    });

    test('mappe le statut Currently Airing', () async {
      final mock = MockClient((_) async =>
          _ok([_jikanAnime(status: 'Currently Airing')]));
      final m = (await JikanClient(client: mock).searchByTitle('x')).first;
      expect(m.status, ReleaseStatus.releasing);
    });

    test('mappe le statut Not yet aired', () async {
      final mock = MockClient(
          (_) async => _ok([_jikanAnime(status: 'Not yet aired')]));
      final m = (await JikanClient(client: mock).searchByTitle('x')).first;
      expect(m.status, ReleaseStatus.notYetReleased);
    });

    test('gère score null', () async {
      final anime = _jikanAnime()..remove('score');
      final mock = MockClient((_) async => _ok([anime]));
      final m = (await JikanClient(client: mock).searchByTitle('x')).first;
      expect(m.averageScore, isNull);
    });

    test('gère episodes null', () async {
      final anime = Map<String, dynamic>.from(_jikanAnime())
        ..['episodes'] = null;
      final mock = MockClient((_) async => _ok([anime]));
      final m = (await JikanClient(client: mock).searchByTitle('x')).first;
      expect(m.episodes, isNull);
    });

    test('gère durée "Unknown"', () async {
      final anime = Map<String, dynamic>.from(_jikanAnime())
        ..['duration'] = 'Unknown';
      final mock = MockClient((_) async => _ok([anime]));
      final m = (await JikanClient(client: mock).searchByTitle('x')).first;
      expect(m.durationMinutes, isNull);
    });

    test('parse durée "1 hr 30 min"', () async {
      final anime = Map<String, dynamic>.from(_jikanAnime())
        ..['duration'] = '1 hr 30 min';
      final mock = MockClient((_) async => _ok([anime]));
      final m = (await JikanClient(client: mock).searchByTitle('x')).first;
      expect(m.durationMinutes, 90);
    });

    test('liste vide si data est vide', () async {
      final mock = MockClient((_) async => _ok([]));
      final results = await JikanClient(client: mock).searchByTitle('rien');
      expect(results, isEmpty);
    });

    test('lance JikanException sur HTTP 500', () async {
      final mock = MockClient((_) async => _err(500));
      await expectLater(
        JikanClient(client: mock).searchByTitle('test'),
        throwsA(
          isA<JikanException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('lance JikanException sur HTTP 429', () async {
      final mock = MockClient((_) async => _err(429));
      await expectLater(
        JikanClient(client: mock).searchByTitle('test'),
        throwsA(isA<JikanException>()),
      );
    });
  });
}
