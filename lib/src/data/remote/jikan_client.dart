/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Client Jikan v4 (fallback quand AniList est indisponible).
///
/// ## Mapping Jikan → Media
/// | Jikan              | Media          | Notes                                      |
/// |--------------------|----------------|--------------------------------------------|
/// | `mal_id`           | `malId`        | Utilisé aussi comme `anilistId` temporaire |
/// | `titles[0].title`  | `title.romaji` | Premier titre (romaji ou original)         |
/// | `title_english`    | `title.english`| Titre anglais officiel                     |
/// | `title_japanese`   | `title.native` | Titre japonais                             |
/// | `type`             | `format`       | Converti via [_formatFromJikan]            |
/// | `status`           | `status`       | Converti via [_statusFromJikan]            |
/// | `episodes`         | `episodes`     | Peut être null si en cours                 |
/// | `duration`         | `durationMinutes` | Ex : "24 min per ep" → 24              |
/// | `season`           | `season`       | Converti via [_seasonFromJikan]            |
/// | `year`             | `seasonYear`   | Année de diffusion                         |
/// | `images.jpg.large_image_url` | `coverUrl` | URL de la couverture              |
/// | `synopsis`         | `description`  | Synopsis                                   |
/// | `genres[].name`    | `genres`       | Liste des genres                           |
/// | `score`            | `averageScore` | Score 0.0–10.0 → multiplié par 10 → 0–100 |
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/models/anime_format.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/media.dart';

/// Base URL de l'API Jikan v4.
const _kBaseUrl = 'https://api.jikan.moe/v4';

/// Exception levée lors d'une erreur Jikan.
class JikanException implements Exception {
  final String message;
  final int? statusCode;

  const JikanException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'JikanException[$statusCode]: $message'
      : 'JikanException: $message';
}

/// Client Jikan v4 — fallback AniList.
///
/// Injectez un [http.Client] personnalisé (ex. [MockClient]) pour les tests.
class JikanClient {
  final http.Client _http;

  JikanClient({http.Client? client}) : _http = client ?? http.Client();

  /// Recherche des animes par titre via GET /anime?q=...
  ///
  /// Retourne une liste de [Media] mappés depuis la réponse Jikan.
  Future<List<Media>> searchByTitle(String q) async {
    final uri = Uri.parse('$_kBaseUrl/anime').replace(
      queryParameters: {'q': q, 'sfw': 'true'},
    );

    final response = await _http.get(uri, headers: {'Accept': 'application/json'});

    if (response.statusCode != 200) {
      throw JikanException(
        'Réponse HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];

    return data
        .map((e) => _mediaFromJikan(e as Map<String, dynamic>))
        .toList();
  }

  /// Mappe un nœud anime Jikan vers [Media].
  static Media _mediaFromJikan(Map<String, dynamic> json) {
    final malId = json['mal_id'] as int? ?? 0;

    // Titres
    final romaji = (json['title'] as String?) ??
        ((json['titles'] as List<dynamic>?)?.isNotEmpty == true
            ? ((json['titles'] as List<dynamic>).first
                    as Map<String, dynamic>)['title'] as String?
            : null);
    final english = json['title_english'] as String?;
    final native = json['title_japanese'] as String?;

    // Couverture
    final images = json['images'] as Map<String, dynamic>?;
    final jpgImages = images?['jpg'] as Map<String, dynamic>?;
    final coverUrl = jpgImages?['large_image_url'] as String? ??
        jpgImages?['image_url'] as String?;

    // Score : Jikan donne 0.0–10.0, on convertit en 0–100.
    final scoreRaw = json['score'];
    final int? averageScore = scoreRaw != null
        ? ((scoreRaw as num) * 10).round()
        : null;

    // Durée : "24 min per ep" → 24
    final durationStr = json['duration'] as String?;
    final durationMinutes = _parseDuration(durationStr);

    // Genres
    final genresRaw = json['genres'] as List<dynamic>?;
    final genres = genresRaw
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList() ??
        const <String>[];

    return Media(
      anilistId: malId,   // Pas d'ID AniList depuis Jikan — on utilise malId
      malId: malId,
      title: MediaTitle(romaji: romaji, english: english, native: native),
      format: _formatFromJikan(json['type'] as String?),
      status: _statusFromJikan(json['status'] as String?),
      episodes: json['episodes'] as int?,
      durationMinutes: durationMinutes,
      season: _seasonFromJikan(json['season'] as String?),
      seasonYear: json['year'] as int?,
      coverUrl: coverUrl,
      description: json['synopsis'] as String?,
      genres: genres,
      averageScore: averageScore,
    );
  }

  /// Convertit le type Jikan en [AnimeFormat].
  static AnimeFormat _formatFromJikan(String? type) => switch (type) {
        'TV' => AnimeFormat.tv,
        'TV Special' => AnimeFormat.special,
        'Movie' => AnimeFormat.movie,
        'OVA' => AnimeFormat.ova,
        'ONA' => AnimeFormat.ona,
        'Special' => AnimeFormat.special,
        'Music' => AnimeFormat.music,
        _ => AnimeFormat.unknown,
      };

  /// Convertit le statut Jikan en [ReleaseStatus].
  static ReleaseStatus _statusFromJikan(String? status) => switch (status) {
        'Finished Airing' => ReleaseStatus.finished,
        'Currently Airing' => ReleaseStatus.releasing,
        'Not yet aired' => ReleaseStatus.notYetReleased,
        _ => ReleaseStatus.unknown,
      };

  /// Convertit la saison Jikan en [AnimeSeason].
  static AnimeSeason? _seasonFromJikan(String? season) => switch (season) {
        'winter' => AnimeSeason.winter,
        'spring' => AnimeSeason.spring,
        'summer' => AnimeSeason.summer,
        'fall' => AnimeSeason.fall,
        _ => null,
      };

  /// Parse une chaîne de durée Jikan ("24 min per ep", "1 hr 30 min") en minutes.
  static int? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'Unknown') return null;
    var total = 0;
    final hrMatch = RegExp(r'(\d+)\s*hr').firstMatch(raw);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(raw);
    if (hrMatch != null) total += int.parse(hrMatch.group(1)!) * 60;
    if (minMatch != null) total += int.parse(minMatch.group(1)!);
    return total > 0 ? total : null;
  }
}
