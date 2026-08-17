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
/// 1. GET `anime-sama.pw` → parse un domaine candidat.
/// 2. Suit une éventuelle redirection finale (HEAD) pour obtenir le vrai hôte.
/// 3. Fallback `anime-sama.to` si quoi que ce soit échoue.
///
/// Best-effort : n'échoue jamais (renvoie au pire [kFallbackDomain]).
Future<String> resolveCurrentDomain(HttpFetcher fetch) async {
  String? resolved;
  try {
    final resp = await fetch(kEntryPointUrl, headers: kHeadersBase);
    if (resp.ok) {
      resolved = parseDomainFromEntryHtml(resp.body);
    }
  } catch (_) {
    // ignoré : on retombe sur le fallback
  }

  if (resolved != null && resolved.isNotEmpty) {
    final finalDomain = await _resolveFinalDomain(fetch, resolved);
    if (finalDomain.isNotEmpty) resolved = finalDomain;
  }

  return (resolved != null && resolved.isNotEmpty) ? resolved : kFallbackDomain;
}

/// Suit la redirection finale de `https://<domain>` et renvoie l'hôte final.
/// Port de `resolve_final_domain` : HEAD avec suivi des redirections, on lit
/// l'hôte de l'URL finale. Renvoie [domain] inchangé si échec.
Future<String> _resolveFinalDomain(HttpFetcher fetch, String domain) async {
  try {
    final resp = await fetch(
      'https://$domain',
      method: HttpMethod.head,
      headers: kHeadersBase,
    );
    // `package:http` suit les redirections ; l'en-tête location (si présent en
    // bout de chaîne) ou l'hôte demandé fait foi. On lit un éventuel Location.
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
