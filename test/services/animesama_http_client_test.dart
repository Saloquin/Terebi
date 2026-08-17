import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:test/test.dart';

/// Fetcher mock : renvoie une réponse fixe et enregistre le dernier appel.
/// Sert de base à tous les tests de scraping (aucun réseau réel).
class FakeFetcher {
  HttpResponse response;
  String? lastUrl;
  HttpMethod? lastMethod;
  Map<String, String>? lastHeaders;
  Map<String, String>? lastQuery;
  bool? lastFollowRedirects;

  FakeFetcher(this.response);

  Future<HttpResponse> call(
    String url, {
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    Map<String, String>? query,
    bool followRedirects = true,
  }) async {
    lastUrl = url;
    lastMethod = method;
    lastHeaders = headers;
    lastQuery = query;
    lastFollowRedirects = followRedirects;
    return response;
  }
}

void main() {
  group('HttpResponse', () {
    test('ok est vrai pour 2xx, faux sinon', () {
      expect(const HttpResponse(statusCode: 200).ok, isTrue);
      expect(const HttpResponse(statusCode: 204).ok, isTrue);
      expect(const HttpResponse(statusCode: 302).ok, isFalse);
      expect(const HttpResponse(statusCode: 404).ok, isFalse);
    });

    test('header lit une clé insensible à la casse', () {
      const r = HttpResponse(
        statusCode: 302,
        headers: {'location': 'https://video.sibnet.ru/final.mp4'},
      );
      expect(r.header('Location'), 'https://video.sibnet.ru/final.mp4');
      expect(r.header('LOCATION'), 'https://video.sibnet.ru/final.mp4');
      expect(r.header('absent'), isNull);
    });
  });

  group('HttpFetcher (typedef via FakeFetcher)', () {
    test('respecte la signature et transmet les arguments', () async {
      final fake = FakeFetcher(const HttpResponse(statusCode: 200, body: 'ok'));
      final HttpFetcher fetcher = fake.call;

      final res = await fetcher(
        'https://anime-sama.to/catalogue/',
        method: HttpMethod.get,
        headers: const {'user-agent': 'test'},
        query: const {'search': 'dr stone'},
        followRedirects: false,
      );

      expect(res.body, 'ok');
      expect(fake.lastUrl, 'https://anime-sama.to/catalogue/');
      expect(fake.lastMethod, HttpMethod.get);
      expect(fake.lastHeaders, {'user-agent': 'test'});
      expect(fake.lastQuery, {'search': 'dr stone'});
      expect(fake.lastFollowRedirects, isFalse);
    });
  });
}
