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

  group('identifyHosterName / parseHosterSources', () {
    test('identifyHosterName identifie les principaux hébergeurs', () {
      expect(identifyHosterName('https://sendvid.com/embed/abc'), 'Sendvid');
      expect(identifyHosterName('https://video.sibnet.ru/shell.php?videoid=123'), 'Sibnet');
      expect(identifyHosterName('https://vidmoly.to/embed-xyz.html'), 'Vidmoly');
      expect(identifyHosterName('https://voe.sx/e/def'), 'Voe');
      expect(identifyHosterName('https://filemoon.sx/e/ghi'), 'Filemoon');
      expect(identifyHosterName('https://streamtape.com/e/jkl'), 'Streamtape');
      expect(identifyHosterName('https://doodstream.com/e/mno'), 'Doodstream');
      expect(identifyHosterName('https://mp4upload.com/embed-pqr.html'), 'Mp4Upload');
      expect(identifyHosterName('https://other.example/embed/1'), 'Lecteur');
    });

    test('parseHosterSources filtre les fantômes et numérote les doublons', () {
      final raw = [
        'https://sendvid.com/embed/abc1',
        'https://video.sibnet.ru/shell.php?videoid=', // fantôme (sans id)
        'https://video.sibnet.ru/shell.php?videoid=12345',
        'https://sendvid.com/embed/abc2',
        'https://vidmoly.to/embed-xyz.html',
      ];
      final sources = parseHosterSources(raw);
      expect(sources.length, 4);
      expect(sources[0].name, 'Sendvid 1');
      expect(sources[0].embedUrl, 'https://sendvid.com/embed/abc1');
      expect(sources[1].name, 'Sibnet');
      expect(sources[1].embedUrl, 'https://video.sibnet.ru/shell.php?videoid=12345');
      expect(sources[2].name, 'Sendvid 2');
      expect(sources[2].embedUrl, 'https://sendvid.com/embed/abc2');
      expect(sources[3].name, 'Vidmoly');
    });
  });

  group('Sendvid extraction & multi-hoster resolution', () {
    test('extractSendvidDirectUrl extrait depuis balise source', () {
      const html = '''
        <div class="video-container">
          <video id="video">
            <source src="https://media.sendvid.com/mp4/test1234.mp4" type="video/mp4"/>
          </video>
        </div>
      ''';
      expect(extractSendvidDirectUrl(html), 'https://media.sendvid.com/mp4/test1234.mp4');
    });

    test('extractSendvidDirectUrl extrait depuis variable JS video_source', () {
      const html = '''
        <script>
          var video_source = "https://media.sendvid.com/mp4/video_from_js.mp4";
        </script>
      ''';
      expect(extractSendvidDirectUrl(html), 'https://media.sendvid.com/mp4/video_from_js.mp4');
    });

    test('resolveSendvid injecte desktop User-Agent et Referer', () async {
      final fetch = RoutedFetcher({
        'sendvid.com/embed/abc': const HttpResponse(
          statusCode: 200,
          body: '<source src="https://sendvid.com/stream.mp4">',
        ),
      });
      final direct = await resolveSendvid(fetch.call, 'https://sendvid.com/embed/abc');
      expect(direct, 'https://sendvid.com/stream.mp4');
    });

    test('resolveHosterSource résout Sendvid avec en-têtes HTTP', () async {
      final fetch = RoutedFetcher({
        'sendvid.com/embed/abc': const HttpResponse(
          statusCode: 200,
          body: '<source src="https://sendvid.com/stream.mp4">',
        ),
      });
      final src = VideoHosterSource(name: 'Sendvid', embedUrl: 'https://sendvid.com/embed/abc');
      final resolved = await resolveHosterSource(fetch.call, 'anime-sama.to', src);
      expect(resolved, isNotNull);
      expect(resolved!.directStreamUrl, 'https://sendvid.com/stream.mp4');
      expect(resolved.httpHeaders['Referer'], 'https://sendvid.com/');
      expect(resolved.httpHeaders['User-Agent'], isNotEmpty);
    });

    test('resolveHosterSource résout Sibnet avec en-têtes HTTP', () async {
      final fetch = RoutedFetcher({
        'shell.php': const HttpResponse(
          statusCode: 200,
          body: 'player.src([{src: "/v/hash1/999.mp4"',
        ),
        '/v/hash1/999.mp4': const HttpResponse(
          statusCode: 302,
          headers: {'location': 'https://video.sibnet.ru/999_final.mp4'},
        ),
      });
      final src = VideoHosterSource(name: 'Sibnet', embedUrl: 'https://video.sibnet.ru/shell.php?videoid=999');
      final resolved = await resolveHosterSource(fetch.call, 'anime-sama.to', src);
      expect(resolved, isNotNull);
      expect(resolved!.directStreamUrl, 'https://video.sibnet.ru/999_final.mp4');
      expect(resolved.httpHeaders['Referer'], 'https://video.sibnet.ru/');
      expect(resolved.httpHeaders['User-Agent'], isNotEmpty);
    });
  });
}
