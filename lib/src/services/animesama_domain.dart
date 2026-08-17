/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Résolution du domaine courant d'anime-sama. Le site change régulièrement de
/// TLD (`.to`, `.fr`…) ; `anime-sama.pw` sert de point d'entrée stable qui
/// pointe vers le domaine actif. Port de `get_current_domain_name` /
/// `resolve_final_domain` (anime_sama.py:662-697).
///
/// La logique de parsing HTML est isolée (pure, testable sans réseau) de la
/// partie réseau (redirections), injectée via [HttpFetcher].
library;

import 'package:html/parser.dart' as html_parser;

import 'animesama_http_client.dart';

/// Domaine de repli si la résolution échoue (identique au Python
/// `FALLBACK_DOMAIN`).
const String kFallbackDomain = 'anime-sama.to';

/// URL du point d'entrée stable qui redirige vers le domaine courant.
const String kEntryPointUrl = 'https://anime-sama.pw/';

/// User-Agent commun à toutes les requêtes anime-sama (IDENTIQUE au Python
/// `HEADERS_BASE` — un UA différent peut être bloqué par le site).
const Map<String, String> kHeadersBase = {
  'user-agent':
      'Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0',
  'accept-language': 'en-US,en;q=0.5',
  'connection': 'keep-alive',
};

/// Extrait le domaine anime-sama depuis le HTML du point d'entrée `.pw`.
///
/// Port de `get_current_domain_name` (partie parsing) : parcourt les `<button>`
/// et `<a>`, retient le premier texte contenant `anime-sama.<tld>` (avec un
/// point, hors `.pw`), sinon le premier `href` contenant `anime-sama` (hors
/// `.pw`). Renvoie `null` si rien trouvé (l'appelant retombe sur le fallback).
String? parseDomainFromEntryHtml(String htmlContent) {
  final doc = html_parser.parse(htmlContent);
  for (final tag in doc.querySelectorAll('button, a')) {
    final text = tag.text.trim();
    if (text.contains('anime-sama') &&
        text.contains('.') &&
        !text.contains('pw')) {
      return text;
    }
    final href = tag.attributes['href'];
    if (href != null && href.contains('anime-sama') && !href.contains('pw')) {
      final match = RegExp(r'https?://([^/]+)').firstMatch(href);
      if (match != null) return match.group(1);
    }
  }
  return null;
}

/// Résout le domaine courant d'anime-sama via [fetch].
///
/// Stratégie (fiabilité > fraîcheur) : on privilégie [kFallbackDomain]
/// (`anime-sama.to`), le domaine dont la STRUCTURE HTML est celle que le
/// scraping sait lire. Les miroirs annoncés par `anime-sama.pw` (`.si`, `.fr`…)
/// servent souvent un HTML différent (recherche ignorée, URLs relatives) qui
/// casse le scraping — on ne les utilise donc QUE si `.to` est injoignable.
///
/// 1. Si `anime-sama.to` répond (HEAD 2xx/3xx) → on le garde.
/// 2. Sinon, on interroge `anime-sama.pw` pour un domaine de secours, en
///    suivant sa redirection finale.
/// 3. Ultime repli : [kFallbackDomain].
///
/// Best-effort : n'échoue jamais.
Future<String> resolveCurrentDomain(HttpFetcher fetch) async {
  // 1. anime-sama.to d'abord : structure connue, scraping fiable.
  if (await _isReachable(fetch, kFallbackDomain)) {
    return kFallbackDomain;
  }

  // 2. Secours : domaine annoncé par le point d'entrée .pw.
  String? resolved;
  try {
    final resp = await fetch(kEntryPointUrl, headers: kHeadersBase);
    if (resp.ok) resolved = parseDomainFromEntryHtml(resp.body);
  } catch (_) {
    // ignoré
  }
  if (resolved != null && resolved.isNotEmpty) {
    final finalDomain = await _resolveFinalDomain(fetch, resolved);
    if (finalDomain.isNotEmpty) resolved = finalDomain;
  }

  // 3. Repli ultime.
  return (resolved != null && resolved.isNotEmpty) ? resolved : kFallbackDomain;
}

/// Vrai si `https://<domain>/catalogue/` répond avec un statut exploitable.
Future<bool> _isReachable(HttpFetcher fetch, String domain) async {
  try {
    final resp = await fetch(
      'https://$domain/catalogue/',
      method: HttpMethod.head,
      headers: kHeadersBase,
    );
    // 2xx (ok) suffit ; certains hôtes répondent 200 direct.
    return resp.ok;
  } catch (_) {
    return false;
  }
}

/// Suit la redirection finale de `https://<domain>` et renvoie l'hôte final.
/// Port de `resolve_final_domain` : HEAD en SUIVANT les redirections, on lit
/// l'hôte de l'URL FINALE (ex. anime-sama.si redirige vers anime-sama.to).
/// Renvoie [domain] inchangé si échec.
Future<String> _resolveFinalDomain(HttpFetcher fetch, String domain) async {
  try {
    final resp = await fetch(
      'https://$domain',
      method: HttpMethod.head,
      headers: kHeadersBase,
      // ignore: avoid_redundant_argument_values
      followRedirects: true,
    );
    // URL finale après redirections (comme urlparse(resp.url).hostname du Python).
    final finalUrl = resp.finalUrl;
    if (finalUrl != null && finalUrl.isNotEmpty) {
      final host = Uri.tryParse(finalUrl)?.host;
      if (host != null && host.isNotEmpty) return host;
    }
    // Repli : un éventuel header Location (redirection non suivie).
    final location = resp.header('location');
    if (location != null && location.isNotEmpty) {
      final host = Uri.tryParse(location)?.host;
      if (host != null && host.isNotEmpty) return host;
    }
  } catch (_) {
    // ignoré
  }
  return domain;
}
