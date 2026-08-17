import 'dart:io';

import 'package:terebi/src/services/animesama_domain.dart';
import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:test/test.dart';

/// Fetcher mock scénarisé : renvoie une réponse selon l'URL demandée.
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
    for (final entry in routes.entries) {
      if (url.contains(entry.key)) return entry.value;
    }
    return const HttpResponse(statusCode: 404);
  }
}

void main() {
  group('parseDomainFromEntryHtml', () {
    test('retient le lien anime-sama hors .pw depuis un href', () {
      const htmlContent = '''
        <html><body>
          <a href="https://anime-sama.pw/">Ancien</a>
          <a href="https://anime-sama.to/">Accéder au site</a>
        </body></html>
      ''';
      expect(parseDomainFromEntryHtml(htmlContent), 'anime-sama.to');
    });

    test('retient le texte du bouton contenant anime-sama.<tld>', () {
      const htmlContent = '''
        <html><body>
          <button>anime-sama.fr</button>
        </body></html>
      ''';
      expect(parseDomainFromEntryHtml(htmlContent), 'anime-sama.fr');
    });

    test('ignore les mentions .pw', () {
      const htmlContent = '''
        <html><body>
          <a href="https://anime-sama.pw/mirror">anime-sama.pw</a>
        </body></html>
      ''';
      expect(parseDomainFromEntryHtml(htmlContent), isNull);
    });

    test('null si aucun domaine trouvé', () {
      expect(parseDomainFromEntryHtml('<html><body>rien</body></html>'), isNull);
    });

    // Équivalence Python : sur le vrai HTML enregistré d'anime-sama.pw, le
    // parseur Dart doit renvoyer EXACTEMENT ce que renvoie le Python
    // (get_current_domain_name) — vérité de référence 'anime-sama.si'.
    test('vrai HTML anime-sama.pw -> même résultat que Python', () {
      final file = File('test/fixtures/entry_pw.html');
      if (!file.existsSync()) {
        markTestSkipped('fixture entry_pw.html absente');
        return;
      }
      final htmlContent = file.readAsStringSync();
      expect(parseDomainFromEntryHtml(htmlContent), 'anime-sama.si');
    });
  });

  group('resolveCurrentDomain', () {
    test('résout le domaine depuis le point d\'entrée', () async {
      final fetch = RoutedFetcher({
        'anime-sama.pw': const HttpResponse(
          statusCode: 200,
          body: '<a href="https://anime-sama.to/">Site</a>',
        ),
        // HEAD sur anime-sama.to : pas de redirection -> domaine inchangé.
        'https://anime-sama.to': const HttpResponse(statusCode: 200),
      });
      expect(await resolveCurrentDomain(fetch.call), 'anime-sama.to');
    });

    test('suit la redirection finale (Location)', () async {
      final fetch = RoutedFetcher({
        'anime-sama.pw': const HttpResponse(
          statusCode: 200,
          body: '<a href="https://anime-sama.fr/">Site</a>',
        ),
        'https://anime-sama.fr': const HttpResponse(
          statusCode: 301,
          headers: {'location': 'https://anime-sama.org/'},
        ),
      });
      expect(await resolveCurrentDomain(fetch.call), 'anime-sama.org');
    });

    test('fallback anime-sama.to si le point d\'entrée est inaccessible',
        () async {
      final fetch = RoutedFetcher(const {}); // tout renvoie 404
      expect(await resolveCurrentDomain(fetch.call), kFallbackDomain);
    });

    test('fallback si le HTML ne contient aucun domaine', () async {
      final fetch = RoutedFetcher({
        'anime-sama.pw':
            const HttpResponse(statusCode: 200, body: '<body>vide</body>'),
      });
      expect(await resolveCurrentDomain(fetch.call), kFallbackDomain);
    });
  });
}
