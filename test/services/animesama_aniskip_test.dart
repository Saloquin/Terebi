import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_aniskip.dart';
import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:test/test.dart';

class RoutedFetcher {
  final Map<String, HttpResponse> routes;
  final List<String> calls = [];
  RoutedFetcher(this.routes);
  Future<HttpResponse> call(
    String url, {
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    Map<String, String>? query,
    bool followRedirects = true,
  }) async {
    calls.add(url);
    for (final e in routes.entries) {
      if (url.contains(e.key)) return e.value;
    }
    return const HttpResponse(statusCode: 404);
  }
}

void main() {
  final exp = () {
    final f = File('test/fixtures/aniskip.expected.json');
    return f.existsSync()
        ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
        : null;
  }();

  group('skipQueries (équivalence Python)', () {
    test('Dr Stone saison 3 -> mêmes requêtes', () {
      final q = skipQueries('Dr Stone', saison: 'Saison 3');
      if (exp != null) {
        expect(q, (exp['skip_queries_drstone_s3'] as List).cast<String>());
      }
      expect(q, ['Dr Stone Season 3', 'Dr Stone 3rd Season', 'Dr Stone']);
    });

    test('saison 1 ou absente -> juste le nom', () {
      expect(skipQueries('Naruto'), ['Naruto']);
      expect(skipQueries('Naruto', saison: 'Saison 1'), ['Naruto']);
    });
  });

  group('titleMatches (équivalence Python)', () {
    test('exact et fuzzy', () {
      expect(titleMatches('One Piece', 'One Piece'), isTrue);
      expect(titleMatches('Dr Stone', 'Dr. STONE'), isTrue);
      if (exp != null) {
        expect(titleMatches('One Piece', 'One Piece'),
            exp['title_matches_op']);
        expect(titleMatches('Dr Stone', 'Dr. STONE'),
            exp['title_matches_fuzzy']);
      }
    });
    test('titres sans rapport -> false', () {
      expect(titleMatches('One Piece', 'Naruto Shippuden'), isFalse);
    });
  });

  group('parseAniskipResponse (équivalence Python sur corps réel)', () {
    test('One Piece ep1 -> mêmes timestamps que Python', () {
      final body = File('test/fixtures/aniskip_op21_ep1.json');
      if (!body.existsSync() || exp == null) {
        markTestSkipped('fixtures aniskip absentes');
        return;
      }
      final times = parseAniskipResponse(body.readAsStringSync());
      final expected =
          (exp['fetch_by_mal_id_21_ep1'] as Map).cast<String, dynamic>();
      expect(times, isNotNull);
      for (final k in expected.keys) {
        expect(times![k], closeTo((expected[k] as num).toDouble(), 0.001),
            reason: k);
      }
    });

    test('found=false -> null', () {
      expect(parseAniskipResponse('{"found": false}'), isNull);
    });
  });

  group('parseMalPrefix (équivalence Python sur corps réel)', () {
    test('One Piece -> mêmes (id, name) que Python', () {
      final body = File('test/fixtures/mal_prefix_onepiece.json');
      if (!body.existsSync() || exp == null) {
        markTestSkipped('fixtures mal absentes');
        return;
      }
      final ids = parseMalPrefix(body.readAsStringSync(), 'One Piece');
      final expected = (exp['resolve_mal_ids_onepiece'] as List)
          .map((e) => (e as List))
          .toList();
      expect(ids.length, expected.length);
      for (var i = 0; i < ids.length; i++) {
        expect(ids[i].$1, expected[i][0], reason: 'id[$i]');
        expect(ids[i].$2, expected[i][1], reason: 'name[$i]');
      }
    });
  });

  group('resolveSkipTimes (intégration mockée)', () {
    test('malId fourni -> timestamps depuis aniskip', () async {
      final body = File('test/fixtures/aniskip_op21_ep1.json');
      if (!body.existsSync()) {
        markTestSkipped('fixture aniskip absente');
        return;
      }
      final fetch = RoutedFetcher({
        'api.aniskip.com':
            HttpResponse(statusCode: 200, body: body.readAsStringSync()),
      });
      final st = await resolveSkipTimes(fetch.call,
          animeName: 'One Piece', episode: 1, malId: 21);
      expect(st.hasOpening, isTrue);
      expect(st.opStart, closeTo(28.783, 0.001));
      expect(st.hasEnding, isTrue);
    });

    test('nom vide -> SkipTimes vide, aucune requête', () async {
      final fetch = RoutedFetcher(const {});
      final st =
          await resolveSkipTimes(fetch.call, animeName: '', episode: 1);
      expect(st.isEmpty, isTrue);
      expect(fetch.calls, isEmpty);
    });
  });
}
