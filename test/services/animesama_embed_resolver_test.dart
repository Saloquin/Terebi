import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_embed_resolver.dart';
import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:test/test.dart';

/// Fetcher routé (par sous-chaîne d'URL) pour scénariser sibnet, etc.
class RoutedFetcher {
  final Map<String, HttpResponse> routes;
  final List<String> calls = [];
  final List<bool> followed = [];
  RoutedFetcher(this.routes);

  Future<HttpResponse> call(
    String url, {
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    Map<String, String>? query,
    bool followRedirects = true,
  }) async {
    calls.add(url);
    followed.add(followRedirects);
    for (final e in routes.entries) {
      if (url.contains(e.key)) return e.value;
    }
    return const HttpResponse(statusCode: 404);
  }
}

void main() {
  group('unpackEmbedScripts / extractStreamUrl (équivalence Python)', () {
    test('vrai embed uqload packé -> même script + même m3u8 que Python', () {
      final htmlFile = File('test/fixtures/embed_uqload.html');
      final expFile = File('test/fixtures/embed_uqload.expected.json');
      if (!htmlFile.existsSync() || !expFile.existsSync()) {
        markTestSkipped('fixtures embed uqload absentes');
        return;
      }
      final htmlContent = htmlFile.readAsStringSync();
      final exp = jsonDecode(expFile.readAsStringSync()) as Map<String, dynamic>;

      // 1. Même nombre de scripts dépaquetés + contenu identique.
      final unpacked = unpackEmbedScripts(htmlContent);
      expect(unpacked.length, exp['unpacked_count']);
      expect(unpacked.first, exp['unpacked_full']);

      // 2. Même URL m3u8 extraite (le point dur validé de bout en bout).
      expect(extractStreamUrl(htmlContent), exp['m3u8']);
    });
  });

  group('unpackEmbedScripts (algo P.A.C.K.E.R)', () {
    test('dépaquette un payload simple', () {
      // '0 1'.split -> table {0:hello,1:world} en base >1.
      const packed =
          "eval(function(p,a,c,k,e,d){}('0 1',2,2,'hello|world'.split('|'),0,{}))";
      expect(unpackEmbedScripts(packed), ['hello world']);
    });

    test('aucun payload -> liste vide', () {
      expect(unpackEmbedScripts('<html>pas de script</html>'), isEmpty);
    });
  });

  group('extractStreamUrl (patterns en clair)', () {
    test("pattern file:'...m3u8'", () {
      expect(extractStreamUrl("file: 'https://x.com/a.m3u8?t=1'"),
          'https://x.com/a.m3u8?t=1');
    });
    test('pattern sources:[{file:"..."}]', () {
      expect(extractStreamUrl('sources: [{file:"https://x.com/b.m3u8"}]'),
          'https://x.com/b.m3u8');
    });
    test('décode &amp; en &', () {
      expect(extractStreamUrl("file: 'https://x.com/a.m3u8?a=1&amp;b=2'"),
          'https://x.com/a.m3u8?a=1&b=2');
    });
  });

  group('resolveVideoUrl / sibnet', () {
    test('sibnet : shell.php -> hash -> 302 Location', () async {
      final fetch = RoutedFetcher({
        'shell.php': const HttpResponse(
          statusCode: 200,
          body: 'player.src([{src: "/v/abc123/6229246.mp4"',
        ),
        '/v/abc123/6229246.mp4': const HttpResponse(
          statusCode: 302,
          headers: {'location': 'https://cdn.sibnet.ru/final.mp4'},
        ),
      });
      final url = await resolveVideoUrl(fetch.call, 'anime-sama.to',
          ['https://video.sibnet.ru/shell.php?videoid=6229246']);
      expect(url, 'https://cdn.sibnet.ru/final.mp4');
      // La requête du .mp4 ne doit PAS suivre la redirection.
      expect(fetch.followed.last, isFalse);
    });

    test('cascade : 1er embed KO -> 2e embed donne le flux', () async {
      final fetch = RoutedFetcher({
        'ko.example': const HttpResponse(statusCode: 200, body: 'rien'),
        'ok.example': const HttpResponse(
          statusCode: 200,
          body: 'sources: [{file:"https://x.com/ok.m3u8"}]',
        ),
      });
      final url = await resolveVideoUrl(fetch.call, 'anime-sama.to',
          ['https://ko.example/e', 'https://ok.example/e']);
      expect(url, 'https://x.com/ok.m3u8');
    });

    test('normalise // -> https://', () async {
      final fetch = RoutedFetcher({
        'ok.example': const HttpResponse(
          statusCode: 200,
          body: "file: '//x.com/proto-relative.m3u8'",
        ),
      });
      final url = await resolveVideoUrl(
          fetch.call, 'anime-sama.to', ['https://ok.example/e']);
      expect(url, 'https://x.com/proto-relative.m3u8');
    });
  });
}
