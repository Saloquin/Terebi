import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_dart_resolver.dart';
import 'package:terebi/src/services/animesama_embed_resolver.dart';
import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:terebi/src/services/stream_resolver.dart';
import 'package:test/test.dart';

String _readUtf8(String p) => utf8.decode(File(p).readAsBytesSync());

/// Fetcher qui route sur les fixtures selon l'URL demandée (e2e sans réseau).
class FixtureFetcher {
  Future<HttpResponse> call(
    String url, {
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    Map<String, String>? query,
    bool followRedirects = true,
  }) async {
    // Point d'entrée domaine -> renvoie anime-sama.to.
    if (url.contains('anime-sama.pw')) {
      return const HttpResponse(
          statusCode: 200, body: '<a href="https://anime-sama.to/">S</a>');
    }
    if (url.startsWith('https://anime-sama.to') &&
        method == HttpMethod.head) {
      return const HttpResponse(statusCode: 200);
    }
    // Recherche catalogue.
    if (url.contains('/catalogue/') &&
        (query?.containsKey('search') ?? false)) {
      final f = File('test/fixtures/catalogue_search_drstone.html');
      return f.existsSync()
          ? HttpResponse(statusCode: 200, body: _readUtf8(f.path))
          : const HttpResponse(statusCode: 404);
    }
    // Page anime Dr Stone (saisons).
    if (url.contains('/catalogue/dr-stone/') &&
        !url.contains('saison') &&
        !url.contains('episodes.js')) {
      final f = File('test/fixtures/anime_dr_stone.html');
      return f.existsSync()
          ? HttpResponse(statusCode: 200, body: _readUtf8(f.path))
          : const HttpResponse(statusCode: 404);
    }
    return const HttpResponse(statusCode: 404);
  }
}

void main() {
  final hasFixtures =
      File('test/fixtures/catalogue_search_drstone.html').existsSync() &&
          File('test/fixtures/anime_dr_stone.html').existsSync();

  group('DartAnimeSamaResolver (intégration mockée)', () {
    test('search -> items depuis la fixture catalogue', () async {
      if (!hasFixtures) {
        markTestSkipped('fixtures absentes');
        return;
      }
      final resolver = DartAnimeSamaResolver(fetch: FixtureFetcher().call);
      final items = await resolver.search(query: 'dr stone');
      expect(items, isNotEmpty);
      expect(items.first.title, 'Dr Stone');
      expect(items.first.slug, 'dr-stone');
    });

    test('implémente bien StreamResolver', () {
      final resolver = DartAnimeSamaResolver(fetch: FixtureFetcher().call);
      expect(resolver, isA<StreamResolver>());
    });

    test('skipTimes best-effort -> vide sans réseau AniSkip', () async {
      final resolver = DartAnimeSamaResolver(
        fetch: (url,
                {method = HttpMethod.get,
                headers,
                query,
                followRedirects = true}) async =>
            const HttpResponse(statusCode: 404),
      );
      final st = await resolver.skipTimes(title: 'X', episode: 1);
      expect(st.isEmpty, isTrue);
    });

    test(
        'listSeasons supporte filever hexadécimal, ignore /* */, continue après un trou et aligne les index VF/VOSTFR',
        () async {
      var httpCalls = 0;
      final resolver = DartAnimeSamaResolver(
        fetch: (url,
            {method = HttpMethod.get,
            headers,
            query,
            followRedirects = true}) async {
          httpCalls++;
          if (method == HttpMethod.head &&
              url == 'https://anime-sama.to/catalogue/') {
            return const HttpResponse(statusCode: 200);
          }
          if (url == 'https://anime-sama.to/catalogue/' &&
              (query?.containsKey('search') ?? false)) {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<a href="https://anime-sama.to/catalogue/mock-show/"><h2>Mock Show</h2></a>',
            );
          }
          if (url == 'https://anime-sama.to/catalogue/mock-show/') {
            return const HttpResponse(
              statusCode: 200,
              body: '''
                <script>
                  panneauAnime("Saison 1", "saison1/vostfr");
                  panneauAnime("OAV", "oav/vostfr");
                  panneauAnime("Saison Vide", "vide/vostfr");
                  /*panneauAnime("Saison 2 Partie 2", "saison2-2/vostfr");*/
                  panneauAnime("Saison 2", "saison2/vostfr");
                  <!--panneauAnime("Film HS", "film/vostfr");-->
                  panneauAnime("Kai", "kai/vostfr");
                </script>
              ''',
            );
          }
          // Saison 1 : filever hex commençant par une lettre (VOSTFR + VF)
          if (url ==
              'https://anime-sama.to/catalogue/mock-show/saison1/vostfr/') {
            return const HttpResponse(
                statusCode: 200,
                body: "<script src='episodes.js?filever=e20d0f7c54dd'></script>");
          }
          if (url.endsWith('/saison1/vostfr/episodes.js')) {
            return const HttpResponse(
                statusCode: 200,
                body: "var eps1 = ['https://uqload.vc/embed-abc123.html'];");
          }
          // OAV : VOSTFR uniquement (absent en VF)
          if (url == 'https://anime-sama.to/catalogue/mock-show/oav/vostfr/') {
            return const HttpResponse(
                statusCode: 200,
                body: "<script src='episodes.js?filever=c56d0535c4eb'></script>");
          }
          if (url.endsWith('/oav/vostfr/episodes.js')) {
            return const HttpResponse(
                statusCode: 200,
                body: "var eps1 = ['https://uqload.vc/embed-oav001.html'];");
          }
          if (url == 'https://anime-sama.to/catalogue/mock-show/oav/vf/') {
            return const HttpResponse(statusCode: 404);
          }
          // Saison Vide : 0 épisodes jouables (ne doit PAS couper Saison 2 ni Kai !)
          if (url ==
              'https://anime-sama.to/catalogue/mock-show/vide/vostfr/') {
            return const HttpResponse(
                statusCode: 200,
                body: "<script src='episodes.js?filever=a11111111111'></script>");
          }
          if (url.endsWith('/vide/vostfr/episodes.js')) {
            return const HttpResponse(statusCode: 200, body: "var eps1 = [];");
          }
          // Saison 2 : filever hex (VOSTFR + VF)
          if (url ==
                  'https://anime-sama.to/catalogue/mock-show/saison2/vostfr/' ||
              url == 'https://anime-sama.to/catalogue/mock-show/saison2/vf/') {
            return const HttpResponse(
                statusCode: 200,
                body: "<script src='episodes.js?filever=ab61ae6fa9d0'></script>");
          }
          if (url.endsWith('/saison2/vostfr/episodes.js')) {
            return const HttpResponse(
                statusCode: 200,
                body: "var eps1 = ['https://uqload.vc/embed-s2vostfr.html'];");
          }
          if (url.endsWith('/saison2/vf/episodes.js')) {
            return const HttpResponse(
              statusCode: 200,
              body:
                  "var eps1 = ['https://uqload.vc/embed-s2vf1.html', 'https://uqload.vc/embed-s2vf2.html'];",
            );
          }
          // Kai : après la saison vide et le commentaire HTML
          if (url == 'https://anime-sama.to/catalogue/mock-show/kai/vostfr/') {
            return const HttpResponse(
                statusCode: 200,
                body: "<script src='episodes.js?filever=fd0123456789'></script>");
          }
          if (url.endsWith('/kai/vostfr/episodes.js')) {
            return const HttpResponse(
                statusCode: 200,
                body: "var eps1 = ['https://uqload.vc/embed-kai001.html'];");
          }
          return const HttpResponse(statusCode: 404);
        },
      );

      final seasons = await resolver.listSeasons(title: 'Mock Show');
      expect(
        [for (final s in seasons) (s.index, s.name)],
        [
          (1, 'Saison 1'),
          (2, 'OAV'),
          (3, 'Saison 2'),
          (4, 'Kai'),
        ],
      );

      // L'index 3 (Saison 2) doit rester Saison 2 même en VF (pas décalé par OAV VOSTFR-only).
      final callsBeforeCache = httpCalls;
      final s2VostfrEps =
          await resolver.listEpisodes(title: 'Mock Show', seasonIndex: 3);
      expect(s2VostfrEps, [1]);
      // listSeasons + saison2 VOSTFR étaient en cache -> 0 requête réseau supplémentaire !
      expect(httpCalls, callsBeforeCache);

      final s2VfEps = await resolver.listEpisodes(
        title: 'Mock Show',
        seasonIndex: 3,
        language: PlaybackLanguage.vf,
      );
      expect(s2VfEps, [1, 2]);
    });

    test(
        'resolveStreamSource pour ep 2 ne réutilise JAMAIS preferredSource d\'un autre épisode',
        () async {
      final resolver = DartAnimeSamaResolver(
        fetch: (url,
            {method = HttpMethod.get,
            headers,
            query,
            followRedirects = true}) async {
          if (method == HttpMethod.head &&
              url == 'https://anime-sama.to/catalogue/') {
            return const HttpResponse(statusCode: 200);
          }
          if (url == 'https://anime-sama.to/catalogue/' &&
              (query?.containsKey('search') ?? false)) {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<a href="https://anime-sama.to/catalogue/test-anime/"><h2>Test Anime</h2></a>',
            );
          }
          if (url == 'https://anime-sama.to/catalogue/test-anime/') {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<script>panneauAnime("Saison 1", "saison1/vostfr");</script>',
            );
          }
          if (url ==
              'https://anime-sama.to/catalogue/test-anime/saison1/vostfr/') {
            return const HttpResponse(
              statusCode: 200,
              body: '''
                <script data-source="bdd">
                  var eps1 = ['https://sendvid.com/embed-ep1.html', 'https://sendvid.com/embed-ep2.html'];
                </script>
              ''',
            );
          }
          if (url == 'https://sendvid.com/embed-ep1.html') {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<source src="https://sendvid.com/direct-ep1.mp4" type="video/mp4">',
            );
          }
          if (url == 'https://sendvid.com/embed-ep2.html') {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<source src="https://sendvid.com/direct-ep2.mp4" type="video/mp4">',
            );
          }
          return const HttpResponse(statusCode: 404);
        },
      );

      // Source de l'épisode 1 (avec un hoster inexistant pour ep 2)
      const staleEp1Source = VideoHosterSource(
        name: 'Vidmoly',
        embedUrl: 'https://vidmoly.me/embed-ep1.html',
        directStreamUrl: 'https://vidmoly.me/direct-ep1.mp4',
      );

      // Résolution de l'épisode 2 en passant l'ancienne source de l'épisode 1 en preferredSource
      final source = await resolver.resolveStreamSource(
        title: 'Test Anime',
        episode: 2,
        preferredSource: staleEp1Source,
      );

      // Doit impérativement résoudre l'épisode 2, et JAMAIS renvoyer staleEp1Source !
      expect(source.embedUrl, 'https://sendvid.com/embed-ep2.html');
      expect(source.directStreamUrl, 'https://sendvid.com/direct-ep2.mp4');
    });

    test(
        'resolveStreamSource pour ep 2 respecte le nom du preferredSource quand disponible',
        () async {
      final resolver = DartAnimeSamaResolver(
        fetch: (url,
            {method = HttpMethod.get,
            headers,
            query,
            followRedirects = true}) async {
          if (method == HttpMethod.head &&
              url == 'https://anime-sama.to/catalogue/') {
            return const HttpResponse(statusCode: 200);
          }
          if (url == 'https://anime-sama.to/catalogue/' &&
              (query?.containsKey('search') ?? false)) {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<a href="https://anime-sama.to/catalogue/test-anime2/"><h2>Test Anime 2</h2></a>',
            );
          }
          if (url == 'https://anime-sama.to/catalogue/test-anime2/') {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<script>panneauAnime("Saison 1", "saison1/vostfr");</script>',
            );
          }
          if (url ==
              'https://anime-sama.to/catalogue/test-anime2/saison1/vostfr/') {
            return const HttpResponse(
              statusCode: 200,
              body: '''
                <script data-source="bdd">
                  var eps1 = ['https://ansembed.net/embed-ep1.html', 'https://ansembed.net/embed-ep2.html'];
                  var eps2 = ['https://sendvid.com/embed-ep1.html', 'https://sendvid.com/embed-ep2.html'];
                </script>
              ''',
            );
          }
          if (url == 'https://sendvid.com/embed-ep2.html') {
            return const HttpResponse(
              statusCode: 200,
              body:
                  '<source src="https://sendvid.com/direct-sendvid-ep2.mp4" type="video/mp4">',
            );
          }
          if (url == 'https://ansembed.net/embed-ep2.html') {
            return const HttpResponse(
              statusCode: 200,
              body: '<html>mock ansembed</html>',
            );
          }
          return const HttpResponse(statusCode: 404);
        },
      );

      // L'utilisateur préférait Sendvid à l'épisode 1
      const prefSendvid = VideoHosterSource(
        name: 'Sendvid',
        embedUrl: 'https://sendvid.com/embed-ep1.html',
      );

      final source = await resolver.resolveStreamSource(
        title: 'Test Anime 2',
        episode: 2,
        preferredSource: prefSendvid,
      );

      // Doit sélectionner Sendvid pour l'épisode 2
      expect(source.name, 'Sendvid');
      expect(source.embedUrl, 'https://sendvid.com/embed-ep2.html');
      expect(
          source.directStreamUrl, 'https://sendvid.com/direct-sendvid-ep2.mp4');
    });
  });
}
