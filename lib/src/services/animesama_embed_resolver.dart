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
import 'animesama_seasons.dart';

/// User-Agent desktop moderne pour contourner les blocages de qualité / DRM légers des hébergeurs.
const String kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

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

/// Représente une source vidéo alternative (cyberlocker / hébergeur d'embed).
class VideoHosterSource {
  final String name;
  final String embedUrl;
  final String? directStreamUrl;
  final Map<String, String> httpHeaders;

  const VideoHosterSource({
    required this.name,
    required this.embedUrl,
    this.directStreamUrl,
    this.httpHeaders = const {},
  });

  bool get isResolved =>
      directStreamUrl != null && directStreamUrl!.isNotEmpty;

  VideoHosterSource copyWith({
    String? name,
    String? embedUrl,
    String? directStreamUrl,
    Map<String, String>? httpHeaders,
  }) {
    return VideoHosterSource(
      name: name ?? this.name,
      embedUrl: embedUrl ?? this.embedUrl,
      directStreamUrl: directStreamUrl ?? this.directStreamUrl,
      httpHeaders: httpHeaders ?? this.httpHeaders,
    );
  }

  @override
  String toString() =>
      'VideoHosterSource(name: $name, embed: $embedUrl, direct: $directStreamUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoHosterSource &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          embedUrl == other.embedUrl;

  @override
  int get hashCode => Object.hash(name, embedUrl);
}

/// Identifie le nom lisible de l'hébergeur d'après son URL.
String identifyHosterName(String embedUrl) {
  final low = embedUrl.toLowerCase();
  if (low.contains('sendvid.com')) return 'Sendvid';
  if (low.contains('sibnet.ru')) return 'Sibnet';
  if (low.contains('vidmoly')) return 'Vidmoly';
  if (low.contains('voe.sx') ||
      low.contains('voe-network') ||
      low.contains('voe.net') ||
      low.contains('voe.to')) {
    return 'Voe';
  }
  if (low.contains('filemoon')) return 'Filemoon';
  if (low.contains('streamtape')) return 'Streamtape';
  if (low.contains('dood') || low.contains('ds2play')) return 'Doodstream';
  if (low.contains('mp4upload')) return 'Mp4Upload';
  if (low.contains('myvi.tv')) return 'MyVi';
  return 'Lecteur';
}

/// Extrait la liste ordonnée des sources alternatives depuis une liste d'URLs d'embeds.
/// Ignore les URLs vides ou fantômes (sans identifiant vidéo).
List<VideoHosterSource> parseHosterSources(List<String> embedUrls) {
  final valid = embedUrls.where((u) => urlHasId(u)).toList();
  final totals = <String, int>{};
  for (final rawUrl in valid) {
    final base = identifyHosterName(rawUrl);
    totals[base] = (totals[base] ?? 0) + 1;
  }

  final indices = <String, int>{};
  final result = <VideoHosterSource>[];
  for (final rawUrl in valid) {
    final base = identifyHosterName(rawUrl);
    final idx = (indices[base] ?? 0) + 1;
    indices[base] = idx;
    final name = (totals[base] ?? 0) > 1 ? '$base $idx' : base;
    result.add(VideoHosterSource(name: name, embedUrl: rawUrl));
  }
  return result;
}

/// Extrait l'URL directe du fichier mp4 depuis le HTML d'une page embed Sendvid.
/// Cherche dans <source src="..."> ou la variable JS video_source.
String? extractSendvidDirectUrl(String htmlContent) {
  var m = RegExp(
    r'''<source[^>]+src=["']([^"']+\.mp4[^"']*)["']''',
    caseSensitive: false,
  ).firstMatch(htmlContent);
  if (m != null) return m.group(1)!.replaceAll('&amp;', '&');

  m = RegExp(
    r'''var\s+video_source\s*=\s*["']([^"']+\.mp4[^"']*)["']''',
    caseSensitive: false,
  ).firstMatch(htmlContent);
  if (m != null) return m.group(1)!.replaceAll('&amp;', '&');

  m = RegExp(
    r'''(?:source|file)\s*:\s*["']([^"']+\.mp4[^"']*)["']''',
    caseSensitive: false,
  ).firstMatch(htmlContent);
  if (m != null) return m.group(1)!.replaceAll('&amp;', '&');

  return extractStreamUrl(htmlContent);
}

/// Résout l'URL directe MP4 d'un embed Sendvid.
Future<String?> resolveSendvid(
  HttpFetcher fetch,
  String embedUrl,
) async {
  try {
    final resp = await fetch(
      embedUrl,
      headers: {
        ...kHeadersBase,
        'user-agent': kDesktopUserAgent,
        'referer': 'https://sendvid.com/',
      },
    );
    if (!resp.ok) return null;
    return extractSendvidDirectUrl(resp.body);
  } catch (_) {
    return null;
  }
}

/// Résout un [VideoHosterSource] en flux direct lisible, avec ses headers requis
/// (Referer, User-Agent) pour éviter les blocages de qualité (403).
Future<VideoHosterSource?> resolveHosterSource(
  HttpFetcher fetch,
  String domain,
  VideoHosterSource source,
) async {
  final embedUrl = source.embedUrl;
  final low = embedUrl.toLowerCase();

  if (low.contains('sendvid.com')) {
    final direct = await resolveSendvid(fetch, embedUrl);
    if (direct != null && direct.isNotEmpty) {
      final normalized = direct.startsWith('//') ? 'https:$direct' : direct;
      return source.copyWith(
        directStreamUrl: normalized,
        httpHeaders: {
          'Referer': 'https://sendvid.com/',
          'User-Agent': kDesktopUserAgent,
        },
      );
    }
  } else if (low.contains('sibnet.ru')) {
    final vid = RegExp(r'videoid=(\d+)').firstMatch(embedUrl);
    if (vid != null) {
      final direct = await _resolveSibnet(fetch, vid.group(1)!);
      if (direct != null && direct.isNotEmpty) {
        final normalized = direct.startsWith('//') ? 'https:$direct' : direct;
        return source.copyWith(
          directStreamUrl: normalized,
          httpHeaders: {
            'Referer': 'https://video.sibnet.ru/',
            'User-Agent': kDesktopUserAgent,
          },
        );
      }
    }
  } else {
    final direct = await resolveEmbed(fetch, domain, embedUrl);
    if (direct != null && direct.isNotEmpty) {
      final normalized = direct.startsWith('//') ? 'https:$direct' : direct;
      final referer = low.contains('vidmoly')
          ? 'https://vidmoly.biz/'
          : 'https://$domain/';
      return source.copyWith(
        directStreamUrl: normalized,
        httpHeaders: {
          'Referer': referer,
          'User-Agent': kDesktopUserAgent,
        },
      );
    }
  }
  return null;
}

/// Résout l'URL de flux d'un seul embed [videoId] (réseau).
/// Port EXACT de `get_video_url` : sibnet spécial, sendvid direct, sinon fetch + extract.
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

    // 2. Sendvid direct : page embed -> source MP4.
    if (videoId.contains('sendvid.com')) {
      final sv = await resolveSendvid(fetch, videoId);
      if (sv != null && sv.isNotEmpty) return sv;
    }

    // Vidmoly : .to -> .biz, .net -> .biz (comme le Python).
    var url = videoId;
    if (url.contains('vidmoly.to')) url = url.replaceAll('vidmoly.to', 'vidmoly.biz');
    url = url.replaceAll('vidmoly.net', 'vidmoly.biz');

    final resp = await fetch(url, headers: {
      ...kHeadersBase,
      'user-agent': kDesktopUserAgent,
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
      headers: {
        ...kHeadersBase,
        'user-agent': kDesktopUserAgent,
      },
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
        'user-agent': kDesktopUserAgent,
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
