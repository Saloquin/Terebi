/// Implémentation réelle de [HttpFetcher] basée sur `package:http`.
///
/// Ce fichier est le SEUL de la couche services (avec system_process_runner)
/// à importer `package:http` pour le résolveur Dart — il est exclu de la suite
/// de tests (dépend du réseau réel).
///
/// Gère finement les redirections : `followRedirects: false` permet de lire le
/// `Location` d'une 302 Sibnet sans la suivre (comme `requests`
/// `allow_redirects=False`).
library;

import 'package:http/http.dart' as http;

import 'animesama_http_client.dart';

/// Construit un [HttpFetcher] qui utilise [client] (un `http.Client` partagé,
/// pour réutiliser les connexions et conserver les cookies via l'appelant).
HttpFetcher httpFetcherFromClient(http.Client client) {
  return (
    String url, {
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    Map<String, String>? query,
    bool followRedirects = true,
  }) async {
    final uri = query == null || query.isEmpty
        ? Uri.parse(url)
        : Uri.parse(url).replace(
            queryParameters: {
              ...Uri.parse(url).queryParameters,
              ...query,
            },
          );

    // Requête bas niveau : `http.Request` expose `followRedirects`, contrairement
    // aux helpers `client.get()`. On l'utilise pour capturer une 302 Sibnet.
    final request = http.Request(
      method == HttpMethod.head ? 'HEAD' : 'GET',
      uri,
    )..followRedirects = followRedirects;
    if (headers != null) request.headers.addAll(headers);

    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);

    // En-têtes en minuscules pour un accès insensible à la casse côté logique.
    final lower = <String, String>{};
    response.headers.forEach((k, v) => lower[k.toLowerCase()] = v);

    return HttpResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: lower,
      // URL finale après redirections (pour resolve_final_domain).
      finalUrl: response.request?.url.toString(),
    );
  };
}
