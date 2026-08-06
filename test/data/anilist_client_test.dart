import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/remote/anilist_client.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';

// ---------------------------------------------------------------------------
// Fixtures JSON réalistes
// ---------------------------------------------------------------------------

Map<String, dynamic> _mediaNode({
  int id = 1,
  int? idMal = 1,
  String titleRomaji = 'Shingeki no Kyojin',
  String titleEnglish = 'Attack on Titan',
  String format = 'TV',
  String status = 'FINISHED',
  int? episodes = 25,
  int duration = 24,
  String season = 'SPRING',
  int seasonYear = 2013,
  String coverLarge = 'https://img/large.jpg',
  String? banner = 'https://img/banner.jpg',
  String description = 'Giants.',
  List<String> genres = const ['Action', 'Drama'],
  int averageScore = 84,
  Map<String, dynamic>? nextAiring,
}) =>
    {
      'id': id,
      'idMal': idMal,
      'title': {'romaji': titleRomaji, 'english': titleEnglish, 'native': '進撃の巨人'},
      'format': format,
      'status': status,
      'episodes': episodes,
      'duration': duration,
      'season': season,
      'seasonYear': seasonYear,
      'coverImage': {'large': coverLarge, 'medium': 'https://img/med.jpg'},
      'bannerImage': banner,
      'description': description,
      'genres': genres,
      'averageScore': averageScore,
      'nextAiringEpisode': nextAiring,
    };

String _searchResponse(List<Map<String, dynamic>> media) => jsonEncode({
      'data': {
        'Page': {'media': media},
      },
    });

String _detailResponse(Map<String, dynamic> media) => jsonEncode({
      'data': {'Media': media},
    });

String _relationsResponse(int id, List<Map<String, dynamic>> edges) =>
    jsonEncode({
      'data': {
        'Media': {
          'relations': {'edges': edges},
        },
      },
    });

http.Response _ok(String body) =>
    http.Response(body, 200, headers: {'content-type': 'application/json'});

http.Response _err(int code) => http.Response('Server error', code);

http.Response _graphqlError(String msg) => http.Response(
      jsonEncode({
        'errors': [
          {'message': msg}
        ],
        'data': null,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ─── search ───────────────────────────────────────────────────────────────

  group('AniListClient.search', () {
    test('retourne une liste de Media parsés', () async {
      final mock = MockClient((_) async => _ok(
            _searchResponse([_mediaNode(), _mediaNode(id: 2, idMal: 2)]),
          ));
      final client = AniListClient(client: mock);

      final results = await client.search('attack on titan');

      expect(results, hasLength(2));
      expect(results.first.anilistId, 1);
      expect(results.first.title.english, 'Attack on Titan');
      expect(results.first.format, AnimeFormat.tv);
      expect(results.first.status, ReleaseStatus.finished);
      expect(results.first.episodes, 25);
      expect(results.first.durationMinutes, 24);
      expect(results.first.season, AnimeSeason.spring);
      expect(results.first.seasonYear, 2013);
      expect(results.first.coverUrl, 'https://img/large.jpg');
      expect(results.first.genres, ['Action', 'Drama']);
      expect(results.first.averageScore, 84);
    });

    test('liste vide si Page.media est vide', () async {
      final mock = MockClient((_) async => _ok(_searchResponse([])));
      final results = await AniListClient(client: mock).search('xyz');
      expect(results, isEmpty);
    });

    test('lance AniListException sur HTTP 500', () async {
      final mock = MockClient((_) async => _err(500));
      await expectLater(
        AniListClient(client: mock).search('test'),
        throwsA(
          isA<AniListException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('lance AniListException sur erreur GraphQL', () async {
      final mock = MockClient((_) async => _graphqlError('Not found'));
      await expectLater(
        AniListClient(client: mock).search('test'),
        throwsA(
          isA<AniListException>().having(
            (e) => e.message,
            'message',
            contains('Not found'),
          ),
        ),
      );
    });
  });

  // ─── season ───────────────────────────────────────────────────────────────

  group('AniListClient.season', () {
    test('retourne les médias de la saison avec sort POPULARITY_DESC', () async {
      final capturedRequests = <Map<String, dynamic>>[];
      final mock = MockClient((req) async {
        capturedRequests.add(jsonDecode(req.body) as Map<String, dynamic>);
        return _ok(_searchResponse([
          _mediaNode(season: 'SPRING', seasonYear: 2023),
        ]));
      });

      final results = await AniListClient(client: mock)
          .season(AnimeSeason.spring, 2023);

      expect(results, hasLength(1));
      expect(results.first.season, AnimeSeason.spring);
      expect(results.first.seasonYear, 2023);
      // Vérifie que la variable season est bien envoyée en majuscule AniList.
      expect(
        capturedRequests.first['variables']['season'],
        'SPRING',
      );
    });
  });

  // ─── mediaDetail ──────────────────────────────────────────────────────────

  group('AniListClient.mediaDetail', () {
    test('retourne le Media complet', () async {
      final mock = MockClient((_) async => _ok(_detailResponse(_mediaNode())));
      final media = await AniListClient(client: mock).mediaDetail(1);

      expect(media.anilistId, 1);
      expect(media.malId, 1);
      expect(media.description, 'Giants.');
      expect(media.bannerUrl, 'https://img/banner.jpg');
    });

    test('lance AniListException sur HTTP 429', () async {
      final mock = MockClient((_) async => _err(429));
      await expectLater(
        AniListClient(client: mock).mediaDetail(1),
        throwsA(isA<AniListException>()),
      );
    });
  });

  // ─── relations ────────────────────────────────────────────────────────────

  group('AniListClient.relations', () {
    test('retourne les MediaRelation parsées', () async {
      final mock = MockClient((_) async => _ok(_relationsResponse(1, [
            {
              'relationType': 'SEQUEL',
              'node': {'id': 42},
            },
            {
              'relationType': 'PREQUEL',
              'node': {'id': 7},
            },
          ])));

      final relations = await AniListClient(client: mock).relations(1);

      expect(relations, hasLength(2));
      expect(relations.first.mediaId, 1);
      expect(relations.first.relatedMediaId, 42);
      expect(relations.first.type.anilist, 'SEQUEL');
      expect(relations[1].relatedMediaId, 7);
      expect(relations[1].type.anilist, 'PREQUEL');
    });

    test('liste vide si pas de relations', () async {
      final mock = MockClient(
          (_) async => _ok(_relationsResponse(1, [])));
      final relations = await AniListClient(client: mock).relations(1);
      expect(relations, isEmpty);
    });
  });

  // ─── nextAiring ───────────────────────────────────────────────────────────

  group('AniListClient.nextAiring', () {
    test('retourne AiringSchedule quand nextAiringEpisode présent', () async {
      // nextAiring() fait une requête séparée renvoyant nextAiringEpisode :
      final airingMock = MockClient((_) async => http.Response(
            jsonEncode({
              'data': {
                'Media': {
                  'nextAiringEpisode': {'airingAt': 1700000000, 'episode': 5},
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final schedule =
          await AniListClient(client: airingMock).nextAiring(1);

      expect(schedule, isNotNull);
      expect(schedule!.episode, 5);
      expect(schedule.mediaId, 1);
      expect(
        schedule.airsAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('retourne null si nextAiringEpisode absent', () async {
      final airingMock = MockClient((_) async => http.Response(
            jsonEncode({
              'data': {
                'Media': {'nextAiringEpisode': null},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final schedule =
          await AniListClient(client: airingMock).nextAiring(1);
      expect(schedule, isNull);
    });
  });
}
