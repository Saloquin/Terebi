import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_dart_resolver.dart';
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
  });
}
