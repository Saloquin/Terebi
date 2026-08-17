/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Résolution de l'URL de flux vidéo (m3u8/mp4) depuis un embed. Port fidèle de
/// `AnimeDownloader.get_video_url` / `resolve_video_url` / `_get_sibnet_url` /
/// `_unpack_embed_scripts` (anime_sama.py:925-1041).
///
/// Cascade de patterns (dans l'ordre du Python) :
///   1. Sibnet : suit une 302 vers le .mp4 final.
///   2. `file:'...m3u8'` en clair dans le HTML.
///   3. `sources:[{file:"..."}]`.
///   4. `.mp4` direct.
///   5. Scripts packés `eval(p,a,c,k,e,d)` -> dépaquetage -> m3u8/mp4.
library;

import 'animesama_http_client.dart';
import 'animesama_domain.dart';

/// Déobfusque les scripts packés `eval(function(p,a,c,k,e,d){...}(...))` d'un
/// HTML et renvoie la liste des scripts dépaquetés.
/// Port EXACT de `_unpack_embed_scripts` (algo Dean Edwards P.A.C.K.E.R).
List<String> unpackEmbedScripts(String htmlContent) {
  final pattern = RegExp(
    r"eval\(function\(p,a,c,k,e,d\).*?\}\('(.*?)',\s*(\d+),\s*(\d+),\s*'(.*?)'\.split\('\|'\)",
    dotAll: true,
  );
  final pages = <String>[];
  for (final match in pattern.allMatches(htmlContent)) {
    try {
      final p = match.group(1)!;
      final a = int.parse(match.group(2)!);
      final c = int.parse(match.group(3)!);
      final k = match.group(4)!.split('|');

      final table = <String, String>{};
      for (var i = 0; i < c; i++) {
        if (i < k.length && k[i].isNotEmpty) {
          table[_encode(i, a)] = k[i];
        }
      }
      final unpacked = p.replaceAllMapped(
        RegExp(r'\b\w+\b'),
        (m) => table[m.group(0)] ?? m.group(0)!,
      );
      pages.add(unpacked);
    } catch (_) {
      continue;
    }
  }
  return pages;
}

/// Encode [num] en base [base] (chiffres 0-9a-z, puis char `r+29` si r>35).
/// Port EXACT de la fonction `enc` interne au Python.
/// Cas `base==1` (unaire) traité pour éviter la récursion infinie.
String _encode(int num, int base) {
  const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
  if (base <= 1) return '0' * num; // notation unaire, cas dégénéré
  final head = num < base ? '' : _encode(num ~/ base, base);
  final r = num % base;
  final ch = r > 35 ? String.fromCharCode(r + 29) : digits[r];
  return head + ch;
}

/// Extrait une URL de flux (m3u8/mp4) du HTML d'un embed déjà téléchargé.
/// Port EXACT de la logique de `get_video_url` APRÈS le fetch (patterns 2 à 5).
/// Renvoie `null` si aucun flux trouvé.
String? extractStreamUrl(String htmlContent) {
  // 2. file:'...m3u8...'
  var m = RegExp(r"file:\s*'([^']+\.m3u8[^']*)'").firstMatch(htmlContent);
  if (m != null) return m.group(1)!.replaceAll('&amp;', '&');

  // 3. sources:[{file:"..."}]
  m = RegExp(r'sources:\s*\[\s*\{\s*file:\s*"([^"]+)"').firstMatch(htmlContent);
  if (m != null) return m.group(1)!.replaceAll('&amp;', '&');

  // 4. .mp4 direct
  m = RegExp(r'''(https?://[^\s"']+\.mp4[^\s"']*)''').firstMatch(htmlContent);
  if (m != null) return m.group(1)!.replaceAll('&amp;', '&');

  // 5. Scripts packés -> m3u8 puis mp4.
  for (final unpacked in unpackEmbedScripts(htmlContent)) {
    final m3u8 = RegExp(r'''(https?://[^\s"'\\]+\.m3u8[^\s"'\\]*)''')
        .firstMatch(unpacked);
    if (m3u8 != null) return m3u8.group(1)!.replaceAll('&amp;', '&');
    final mp4 = RegExp(r'''(https?://[^\s"'\\]+\.mp4[^\s"'\\]*)''')
        .firstMatch(unpacked);
    if (mp4 != null) return mp4.group(1)!.replaceAll('&amp;', '&');
  }
  return null;
}

/// Résout l'URL de flux d'un seul embed [videoId] (réseau).
/// Port EXACT de `get_video_url` : sibnet spécial, sinon fetch + extract.
Future<String?> resolveEmbed(
  HttpFetcher fetch,
  String domain,
  String videoId,
) async {
  try {
    // 1. Sibnet : id numérique -> 302 vers le .mp4.
    if (videoId.contains('sibnet.ru')) {
      final vid = RegExp(r'videoid=(\d+)').firstMatch(videoId);
      if (vid != null) return _resolveSibnet(fetch, vid.group(1)!);
    }

    // Vidmoly : .to -> .biz, .net -> .biz (comme le Python).
    var url = videoId;
    if (url.contains('vidmoly.to')) url = url.replaceAll('vidmoly.to', 'vidmoly.biz');
    url = url.replaceAll('vidmoly.net', 'vidmoly.biz');

    final resp = await fetch(url, headers: {
      ...kHeadersBase,
      'accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'referer': 'https://$domain/',
    });
    if (!resp.ok) return null;
    return extractStreamUrl(resp.body);
  } catch (_) {
    return null;
  }
}

/// Résout l'URL Sibnet : GET shell.php?videoid=.. -> hash -> GET .mp4 (302).
/// Port EXACT de `_get_sibnet_url`.
Future<String?> _resolveSibnet(HttpFetcher fetch, String videoId) async {
  try {
    final resp = await fetch(
      'https://video.sibnet.ru/shell.php',
      headers: kHeadersBase,
      query: {'videoid': videoId},
    );
    if (!resp.ok) return null;
    final m =
        RegExp(r'player\.src\(\[\{src: "/v/([^/]+)/').firstMatch(resp.body);
    if (m == null) return null;
    final hash = m.group(1)!;
    final mp4Url = 'https://video.sibnet.ru/v/$hash/$videoId.mp4';
    // Requête SANS suivi de redirection : on lit le Location de la 302.
    final r = await fetch(
      mp4Url,
      headers: {
        ...kHeadersBase,
        'range': 'bytes=0-',
        'accept-encoding': 'identity',
        'referer': 'https://video.sibnet.ru/',
      },
      followRedirects: false,
    );
    if (r.statusCode == 302) return r.header('location');
    return null;
  } catch (_) {
    return null;
  }
}

/// Résout la 1re URL jouable parmi une liste d'embeds (dans l'ordre).
/// Port EXACT de `resolve_video_url`. Normalise `//` -> `https://`.
Future<String?> resolveVideoUrl(
  HttpFetcher fetch,
  String domain,
  List<String> videoIds,
) async {
  for (final id in videoIds) {
    final url = await resolveEmbed(fetch, domain, id);
    if (url != null && url.isNotEmpty) {
      return url.startsWith('//') ? 'https:$url' : url;
    }
  }
  return null;
}
