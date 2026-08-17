/// Domaine pur — AUCUN import de package:flutter ni package:http (testable via
/// `dart test`).
///
/// Abstraction d'exécution de requêtes HTTP GET/HEAD, injectable pour tester la
/// logique de scraping sans réseau (comme [ProcessRunner] l'est pour Python).
///
/// Le résolveur Dart pur (port du wrapper Python anime-sama) construit ses
/// requêtes puis délègue à un [HttpFetcher]. En prod, une implémentation basée
/// sur `package:http` (voir `system_http_fetcher.dart`) ; en test, un mock qui
/// renvoie des fixtures HTML enregistrées depuis anime-sama.
library;

/// Réponse HTTP minimale : status, corps, en-têtes (pour lire `Location` sur
/// une 302 Sibnet et `Set-Cookie` pour la session).
///
/// [headers] a des clés en minuscules (normalisées par l'implémentation réelle)
/// pour un accès insensible à la casse — les tests doivent fournir des clés
/// déjà en minuscules.
class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const HttpResponse({
    required this.statusCode,
    this.body = '',
    this.headers = const {},
  });

  bool get ok => statusCode >= 200 && statusCode < 300;

  /// Valeur d'un en-tête (clé insensible à la casse), ou `null` si absent.
  String? header(String name) => headers[name.toLowerCase()];
}

/// Méthode HTTP supportée par le résolveur (le Python n'utilise que GET/HEAD).
enum HttpMethod { get, head }

/// Effectue une requête HTTP et renvoie sa réponse. Implémentation réelle en
/// prod (`package:http`), mock en test.
///
/// [url]             : URL absolue (le domaine anime-sama est résolu en amont).
/// [method]          : GET (défaut) ou HEAD (sonde d'image CDN).
/// [headers]         : en-têtes de requête (User-Agent, referer, cookie…).
/// [query]           : paramètres de query string ajoutés à [url].
/// [followRedirects] : `true` (défaut) suit les 30x ; `false` pour lire le
///                     `Location` d'une 302 (Sibnet).
typedef HttpFetcher = Future<HttpResponse> Function(
  String url, {
  HttpMethod method,
  Map<String, String>? headers,
  Map<String, String>? query,
  bool followRedirects,
});
