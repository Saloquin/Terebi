/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Récupération des timestamps de skip intro/outro (AniSkip). Port fidèle de
/// `_skip_queries`, `_title_matches`, `_resolve_mal_ids`, `_fetch_aniskip_times`,
/// `_get_skip_times` (anime_sama.py:397-504).
///
/// Approche (inspirée d'ani-skip) : trouver le MAL id de l'anime (fourni par
/// l'appelant si dispo, sinon recherche textuelle sur MyAnimeList), puis
/// interroger api.aniskip.com pour l'épisode. Best-effort : l'absence de
/// timestamps n'est jamais une erreur.
library;

import 'dart:convert';

import 'animesama_http_client.dart';
import 'animesama_domain.dart';
import 'stream_resolver.dart';

/// Génère les requêtes de recherche MAL pour un anime + saison.
/// Port EXACT de `_skip_queries` : ajoute « Season N » / « Nth Season » si
/// saison > 1, puis le nom nu.
List<String> skipQueries(String animeName, {String? saison}) {
  var name = animeName.replaceAll(RegExp(r'\s+'), ' ').trim();
  name = name.replaceAll(
      RegExp(r'\s*[-:]\s*(vostfr|vf)$', caseSensitive: false), '');
  final queries = <String>[];
  final match =
      RegExp(r'saison\s*(\d+)', caseSensitive: false).firstMatch(saison ?? '');
  if (match != null && int.parse(match.group(1)!) > 1) {
    final n = int.parse(match.group(1)!);
    final ordinal = {1: '1st', 2: '2nd', 3: '3rd'}[n] ?? '${n}th';
    queries.add('$name Season $n');
    queries.add('$name $ordinal Season');
  }
  queries.add(name);
  return queries;
}

/// Vrai si [query] et [title] correspondent (inclusion normalisée ou ratio de
/// similarité >= 0.7). Port de `_title_matches` (SequenceMatcher.ratio).
bool titleMatches(String query, String? title) {
  String norm(String? t) =>
      (t ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  final q = norm(query);
  final t = norm(title);
  if (q.isEmpty || t.isEmpty) return false;
  if (q.contains(t) || t.contains(q)) return true;
  return _ratio(q, t) >= 0.7;
}

/// Ratio de similarité type difflib.SequenceMatcher (0..1), basé sur la taille
/// des blocs correspondants. Implémentation Ratcliff/Obershelp simplifiée.
double _ratio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final matches = _matchingBlocks(a, b);
  return 2.0 * matches / (a.length + b.length);
}

/// Somme des longueurs des blocs correspondants (récursif, comme SequenceMatcher).
int _matchingBlocks(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  // Plus longue sous-chaîne commune.
  var bestI = 0, bestJ = 0, bestLen = 0;
  final prev = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    final curr = List<int>.filled(b.length + 1, 0);
    for (var j = 0; j < b.length; j++) {
      if (a[i] == b[j]) {
        curr[j + 1] = prev[j] + 1;
        if (curr[j + 1] > bestLen) {
          bestLen = curr[j + 1];
          bestI = i - bestLen + 1;
          bestJ = j - bestLen + 1;
        }
      }
    }
    prev.setAll(0, curr);
  }
  if (bestLen == 0) return 0;
  return bestLen +
      _matchingBlocks(a.substring(0, bestI), b.substring(0, bestJ)) +
      _matchingBlocks(a.substring(bestI + bestLen), b.substring(bestJ + bestLen));
}

/// Parse la réponse api.aniskip.com en map de timestamps, ou `null` si vide.
/// Port EXACT de la partie parsing de `_fetch_aniskip_times`.
Map<String, double>? parseAniskipResponse(String jsonBody) {
  try {
    final data = jsonDecode(jsonBody) as Map<String, dynamic>;
    if (data['found'] != true) return null;
    final times = <String, double>{};
    for (final result in (data['results'] as List? ?? const [])) {
      final r = result as Map<String, dynamic>;
      final interval = r['interval'] as Map<String, dynamic>? ?? const {};
      final start = interval['start_time'];
      final end = interval['end_time'];
      final type = r['skip_type'];
      if (start != null && end != null && type != null) {
        times['${type}_start'] = (start as num).toDouble();
        times['${type}_end'] = (end as num).toDouble();
      }
      final length = r['episode_length'];
      if (length != null) {
        final l = (length as num).toDouble();
        times['episode_length'] =
            (times['episode_length'] ?? 0) > l ? times['episode_length']! : l;
      }
    }
    return times.isEmpty ? null : times;
  } catch (_) {
    return null;
  }
}

/// Parse la réponse MyAnimeList prefix.json en liste (id, name) filtrée.
/// Port EXACT de la logique de `_resolve_mal_ids`.
List<(int, String?)> parseMalPrefix(String jsonBody, String query) {
  try {
    final data = jsonDecode(jsonBody) as Map<String, dynamic>;
    for (final category in (data['categories'] as List? ?? const [])) {
      final c = category as Map<String, dynamic>;
      if (c['type'] == 'anime') {
        final items = (c['items'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        var matched =
            items.where((it) => titleMatches(query, it['name'] as String?)).toList();
        if (matched.isEmpty) {
          matched = items
              .where((it) => ((it['es_score'] as num?) ?? 0) >= 1.0)
              .toList();
        }
        return matched
            .take(5)
            .map((it) => (it['id'] as int, it['name'] as String?))
            .toList();
      }
    }
  } catch (_) {
    // ignoré
  }
  return const [];
}

/// Interroge api.aniskip.com pour un [malId] + [episode] (réseau).
/// Port de la partie réseau de `_fetch_aniskip_times`.
Future<Map<String, double>?> fetchAniskipTimes(
  HttpFetcher fetch,
  int malId,
  int episode,
) async {
  try {
    final resp = await fetch(
      'https://api.aniskip.com/v1/skip-times/$malId/$episode',
      query: {'types': 'op'}, // op + ed (l'API accepte la répétition ; ed ajouté ci-dessous)
    );
    // L'API Python passe types=[op,ed] ; on refait un appel combiné via query
    // brute pour rester fidèle (op ET ed).
    final resp2 = await fetch(
      'https://api.aniskip.com/v1/skip-times/$malId/$episode?types=op&types=ed',
    );
    final r = resp2.ok ? resp2 : resp;
    if (!r.ok) return null;
    return parseAniskipResponse(r.body);
  } catch (_) {
    return null;
  }
}

/// Résout les timestamps de skip via [fetch]. Port de `_get_skip_times` :
/// essaie le [malId] fourni EN PREMIER, sinon recherche MAL par titre dégradé.
/// Renvoie un [SkipTimes] (vide si rien trouvé — jamais d'exception).
Future<SkipTimes> resolveSkipTimes(
  HttpFetcher fetch, {
  required String animeName,
  required int episode,
  String? saison,
  int? malId,
}) async {
  if (animeName.isEmpty) return const SkipTimes();

  Map<String, double>? times;
  // 1. MAL id fourni (le plus fiable).
  if (malId != null && malId > 0) {
    times = await fetchAniskipTimes(fetch, malId, episode);
  }
  // 2. Repli : recherche du MAL id par titre.
  if (times == null) {
    for (final query in skipQueries(animeName, saison: saison)) {
      final ids = await _resolveMalIds(fetch, query);
      for (final (id, _) in ids) {
        times = await fetchAniskipTimes(fetch, id, episode);
        if (times != null) break;
      }
      if (times != null) break;
    }
  }
  if (times == null) return const SkipTimes();
  return SkipTimes(
    opStart: times['op_start'],
    opEnd: times['op_end'],
    edStart: times['ed_start'],
    edEnd: times['ed_end'],
  );
}

/// Recherche les MAL ids d'une requête sur MyAnimeList prefix.json (réseau).
Future<List<(int, String?)>> _resolveMalIds(
    HttpFetcher fetch, String query) async {
  try {
    final resp = await fetch(
      'https://myanimelist.net/search/prefix.json',
      headers: kHeadersBase,
      query: {'type': 'anime', 'keyword': query},
    );
    if (!resp.ok) return const [];
    return parseMalPrefix(resp.body, query);
  } catch (_) {
    return const [];
  }
}
