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

import 'animesama_http_client.dart';
import 'animesama_domain.dart';

/// Une saison brute telle que scrappée : nom + chemin relatif (ex. `saison1/vostfr`).
class RawSeason {
  final String name;
  final String url;
  const RawSeason(this.name, this.url);
}

/// Extrait les saisons du HTML d'une page anime (`panneauAnime("nom","path")`).
/// Port EXACT de `get_seasons` : exclut le seul artefact de template « nom ».
List<RawSeason> parseSeasons(String htmlContent) {
  final pattern = RegExp(r'panneauAnime\("([^"]+)",\s*"([^"]+)"\)');
  final matches = pattern.allMatches(htmlContent);
  final seasons = <RawSeason>[];
  for (final m in matches) {
    final name = m.group(1)!;
    final path = m.group(2)!;
    if (name.toLowerCase() != 'nom') {
      seasons.add(RawSeason(name, path));
    }
  }
  return seasons;
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
      .replaceAll(RegExp(r'/(vostfr|vf|va|vcn|vkr|vqc)\b'), '')
      .replaceAll(RegExp(r'^/+|/+$'), '');
  return core.isNotEmpty && !core.contains('/');
}

/// Clé de déduplication d'une saison : URL sans suffixe de langue (fusionne
/// VF/VOSTFR), repli sur le nom normalisé. Port de `_season_key`.
String _seasonKey(RawSeason s) {
  var url = s.url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  url = url.replaceAll(RegExp(r'/(vostfr|vf|va|vcn|vkr|vqc)$'), '');
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
  if (u.isEmpty) return false;
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

/// Extrait le `filever` d'une page saison (`episodes.js?filever=(\d+)`).
/// Port de `get_episode_list`. Renvoie `null` si absent.
String? parseFilever(String htmlContent) {
  final m = RegExp(r'episodes\.js\?filever=(\d+)').firstMatch(htmlContent);
  return m?.group(1);
}

/// Parse un `episodes.js` en dict {ep_key: [embed_urls]}.
/// Port EXACT de `get_anime_episode` : chaque `var epsN=[...]` ajoute, pour le
/// i-ème lien, une URL à l'épisode i (dédupliqué, ordre conservé).
Map<String, List<String>> parseEpisodesJs(String content) {
  final embedLinks = <String, List<String>>{};
  final varMatches = RegExp(r'var eps\d+\s*=\s*\[([^\]]+)\]').allMatches(content);
  for (final varMatch in varMatches) {
    final urlsBlock = varMatch.group(1)!;
    final vidUrls = RegExp("'([^']+)'")
        .allMatches(urlsBlock)
        .map((m) => m.group(1)!)
        .toList();
    for (var i = 0; i < vidUrls.length; i++) {
      final key = '${i + 1}';
      final list = embedLinks.putIfAbsent(key, () => <String>[]);
      if (!list.contains(vidUrls[i])) list.add(vidUrls[i]);
    }
  }
  return embedLinks;
}

/// Récupère le filever puis le dict d'épisodes d'une URL de saison (réseau).
/// Port de `get_episode_list` + `get_anime_episode` chaînés.
Future<Map<String, List<String>>> fetchEpisodes(
  HttpFetcher fetch,
  String seasonUrl,
) async {
  final pageResp = await fetch(seasonUrl, headers: kHeadersBase);
  if (!pageResp.ok) return const {};
  final filever = parseFilever(pageResp.body);
  if (filever == null) return const {};
  final jsUrl = '${seasonUrl.replaceAll(RegExp(r'/+$'), '')}/episodes.js';
  final jsResp = await fetch(jsUrl, headers: kHeadersBase, query: {'filever': filever});
  if (!jsResp.ok) return const {};
  return parseEpisodesJs(jsResp.body);
}
