/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Listage des saisons et épisodes anime-sama. Port fidèle de :
///   - `get_seasons` (anime_sama.py:847) — regex panneauAnime(...)
///   - `get_episode_list` (anime_sama.py:867) — filever de episodes.js
///   - `AnimeDownloader.get_anime_episode` (anime_sama.py:904) — var epsN=[...]
///   - `_is_real_season`, `_dedupe_seasons`, `_url_has_id`,
///     `_playable_episode_count` (animesama_resolve.py) — filtrage vraies saisons
///
/// anime-sama capte TOUS les `panneauAnime(...)` de la page (y compris des blocs
/// de recommandations d'AUTRES animes) et déclare « Saison 1..N » alors qu'une
/// seule existe. On ne garde donc que les VRAIES saisons : chemin relatif court
/// ET ayant au moins un épisode réellement jouable.
library;

import 'dart:convert';

import 'animesama_http_client.dart';
import 'animesama_domain.dart';

/// Une saison brute telle que scrappée : nom + chemin relatif (ex. `saison1/vostfr`).
class RawSeason {
  final String name;
  final String url;
  const RawSeason(this.name, this.url);
}

/// Informations completes d'une saison scrappee : dictionnaire d'episodes,
/// jeton de session /api/lien.php (depuis 12/11/2026), metadonnees des liens
/// et noms lisibles des lecteurs hebergeurs.
class SeasonInfo {
  final Map<String, List<String>> episodes;
  final String? jeton;
  final Map<String, String> meta;
  final Map<String, String> lecteurNames;

  const SeasonInfo({
    required this.episodes,
    this.jeton,
    this.meta = const {},
    this.lecteurNames = const {},
  });
}

/// Extrait les saisons du HTML d'une page anime (`panneauAnime("nom","path")`).
/// Port EXACT de `get_seasons` : exclut le seul artefact de template « nom ».
List<RawSeason> parseSeasons(String htmlContent) {
  final pattern = RegExp(
    r'''panneauAnime\s*\(\s*(?:"([^"]+)"|'([^']+)')\s*,\s*(?:"([^"]+)"|'([^']+)')''',
  );
  final matches = pattern.allMatches(htmlContent);
  final seasons = <RawSeason>[];
  for (final m in matches) {
    final name = (m.group(1) ?? m.group(2))!;
    final path = (m.group(3) ?? m.group(4))!;
    if (name.trim().toLowerCase() != 'nom') {
      seasons.add(RawSeason(name, path));
    }
  }
  return seasons;
}

/// Extrait uniquement les saisons ACTIVES (hors commentaires JS `/* ... */`,
/// `// ...` et commentaires HTML `<!-- ... -->`) telles qu'exécutées par le
/// navigateur sur anime-sama.
List<RawSeason> parseActiveSeasons(String htmlContent) {
  // 1. Retire les commentaires blocs JS et HTML (peuvent s'étaler sur N lignes).
  var cleaned = htmlContent
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  // 2. Retire les lignes commentées par `//` (sans casser `https://` dans les URLs).
  cleaned = cleaned
      .split(RegExp(r'\r?\n'))
      .where((line) => !RegExp(r'^\s*//').hasMatch(line))
      .join('\n');
  return parseSeasons(cleaned);
}

/// Vrai si l'entrée est une VRAIE saison (chemin relatif court), pas une reco.
/// Port EXACT de `_is_real_season`.
bool isRealSeason(RawSeason s) {
  final url = s.url.trim().toLowerCase();
  if (url.isEmpty) return false;
  if (url.startsWith('http') || url.startsWith('//') || url.contains('catalogue')) {
    return false;
  }
  // Retire un éventuel suffixe de langue ; il doit rester au plus 1 segment.
  final core = url
      .replaceAll(RegExp(r'/(vostfr|vf|va|vcn|vkr|vqc)\d*\b'), '')
      .replaceAll(RegExp(r'^/+|/+$'), '');
  return core.isNotEmpty && !core.contains('/');
}

/// Clé de déduplication d'une saison : URL sans suffixe de langue (fusionne
/// VF/VOSTFR), repli sur le nom normalisé. Port de `_season_key`.
String _seasonKey(RawSeason s) {
  var url = s.url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  url = url.replaceAll(RegExp(r'/(vostfr|vf|va|vcn|vkr|vqc)\d*$'), '');
  if (url.isNotEmpty) return url;
  return s.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Retire les doublons (même saison en VF/VOSTFR, ou exact). Ordre conservé.
/// Port EXACT de `_dedupe_seasons`.
List<RawSeason> dedupeSeasons(List<RawSeason> seasons) {
  final seen = <String>{};
  final result = <RawSeason>[];
  for (final s in seasons) {
    final key = _seasonKey(s);
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    result.add(s);
  }
  return result;
}

/// Vrai si l'URL vidéo contient un identifiant NON vide (écarte les
/// URLs-coquilles des épisodes fantômes). Port EXACT de `_url_has_id`.
bool urlHasId(String? url) {
  final u = (url ?? '').trim();
  if (u.isEmpty || u == ',') return false;
  if (u.startsWith('lien:')) {
    final id = u.substring(5).trim();
    return id.isNotEmpty && RegExp(r'^\d+$').hasMatch(id);
  }
  final low = u.toLowerCase();
  const emptyPatterns = [
    r'videoid=(?:&|$)',
    r'[?&]oid=(?:&|$)',
    r'embed-\.html',
    r'/embed-?/?(?:\?|#|$)',
    r'[?&#][a-z_]+=(?:&|$)',
  ];
  for (final p in emptyPatterns) {
    if (RegExp(p).hasMatch(low)) return false;
  }
  return true;
}

/// Nombre d'épisodes réellement jouables (au moins une URL avec un id non vide).
/// Port EXACT de `_playable_episode_count`.
int playableEpisodeCount(Map<String, List<String>> eps) {
  var count = 0;
  for (final urls in eps.values) {
    if (urls.any(urlHasId)) count++;
  }
  return count;
}

/// Extrait le `filever` d'une page saison (`episodes.js?filever=<hash|num>`).
/// Supporte les anciens entiers (`5591`) ET les nouveaux hash hexadécimaux
/// (`e20d0f7c54dd`) utilisés par anime-sama. Renvoie `null` si absent.
String? parseFilever(String htmlContent) {
  final m = RegExp(r'episodes\.js\?filever=([a-zA-Z0-9_-]+)')
      .firstMatch(htmlContent);
  return m?.group(1);
}

/// Parse un `episodes.js` en dict {ep_key: [embed_urls]}.
/// Port EXACT de `get_anime_episode` : chaque `var epsN=[...]` ajoute, pour le
/// i-ème lien, une URL à l'épisode i (dédupliqué, ordre conservé).
Map<String, List<String>> parseEpisodesJs(String content) {
  final embedLinks = <String, List<String>>{};
  final varMatches =
      RegExp(r'(?:var|let|const)\s+eps\d+\s*=\s*\[([^\]]*)\]').allMatches(content);
  for (final varMatch in varMatches) {
    final urlsBlock = varMatch.group(1)!;
    final vidUrls = RegExp(r'''['"]([^'"]*)['"]''')
        .allMatches(urlsBlock)
        .map((m) => m.group(1)!.trim())
        .toList();
    for (var i = 0; i < vidUrls.length; i++) {
      final url = vidUrls[i];
      if (url.isEmpty || url == ',') continue;
      final key = '${i + 1}';
      final list = embedLinks.putIfAbsent(key, () => <String>[]);
      if (!list.contains(url)) list.add(url);
    }
  }
  return embedLinks;
}

/// Extrait le jeton de securite (`epsJeton = "..."`) de la page de saison
/// requis par `/api/lien.php` depuis la mise a jour anime-sama du 12/11/2026.
String? parseEpsJeton(String htmlContent) {
  final m =
      RegExp(r'''epsJeton\s*=\s*["']([^"']+)["']''').firstMatch(htmlContent);
  return m?.group(1);
}

/// Extrait la table `epsMeta = { "<id>": ["domaine.com"] }` associant chaque lien
/// en base a son domaine hebergeur.
Map<String, String> parseEpsMeta(String htmlContent) {
  final meta = <String, String>{};
  final m = RegExp(r'''var\s+epsMeta\s*=\s*(\{[\s\S]*?\});''')
      .firstMatch(htmlContent);
  if (m != null) {
    try {
      final decoded = jsonDecode(m.group(1)!);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final val = entry.value;
          if (val is List && val.isNotEmpty && val.first is String) {
            meta[entry.key.toString()] = val.first as String;
          }
        }
      }
    } catch (_) {}
  }
  return meta;
}

/// Extrait la table `lecteursInfos = { "domaine.com": { "nom": "Vidmoly" } }`.
Map<String, String> parseLecteursInfos(String htmlContent) {
  final names = <String, String>{};
  final m = RegExp(r'''var\s+lecteursInfos\s*=\s*(\{[\s\S]*?\});''')
      .firstMatch(htmlContent);
  if (m != null) {
    try {
      final decoded = jsonDecode(m.group(1)!);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final val = entry.value;
          if (val is Map && val['nom'] is String) {
            names[entry.key.toString().toLowerCase()] = val['nom'] as String;
          }
        }
      }
    } catch (_) {}
  }
  return names;
}

/// Recupere l ensemble des informations de la saison (episodes, jeton, meta, lecteurs).
/// Tente d abord le parsing inline (format direct du HTML depuis le 12/11/2026),
/// puis retombe sur `episodes.js` pour la retrocompatibilite.
Future<SeasonInfo> fetchSeasonInfo(
  HttpFetcher fetch,
  String seasonUrl,
) async {
  final cleanSeasonUrl = '${seasonUrl.replaceAll(RegExp(r'/+$'), '')}/';
  final pageResp = await fetch(
    cleanSeasonUrl,
    headers: {
      ...kHeadersBase,
      'referer': cleanSeasonUrl,
    },
  );
  if (!pageResp.ok) return const SeasonInfo(episodes: {});

  var eps = parseEpisodesJs(pageResp.body);
  final jeton = parseEpsJeton(pageResp.body);
  final meta = parseEpsMeta(pageResp.body);
  final lecteurNames = parseLecteursInfos(pageResp.body);

  if (eps.isEmpty) {
    final filever = parseFilever(pageResp.body);
    if (filever != null || pageResp.body.contains('episodes.js')) {
      final jsUrl = '${seasonUrl.replaceAll(RegExp(r'/+$'), '')}/episodes.js';
      final jsResp = await fetch(
        jsUrl,
        headers: {
          ...kHeadersBase,
          'referer': cleanSeasonUrl,
        },
        query: filever != null ? {'filever': filever} : null,
      );
      if (jsResp.ok) {
        eps = parseEpisodesJs(jsResp.body);
      }
    }
  }

  return SeasonInfo(
    episodes: eps,
    jeton: jeton,
    meta: meta,
    lecteurNames: lecteurNames,
  );
}

/// Recupere le dict d episodes d une URL de saison (reseau).
/// Compatible avec l ancien fichier externe `episodes.js` et le nouveau format
/// inline injecte en base dans le HTML.
Future<Map<String, List<String>>> fetchEpisodes(
  HttpFetcher fetch,
  String seasonUrl,
) async {
  final info = await fetchSeasonInfo(fetch, seasonUrl);
  return info.episodes;
}
