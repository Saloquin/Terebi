/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Modèle central : un média anime (série, film, OVA…) et ses métadonnées.
library;

import 'anime_format.dart';
import 'enums.dart';

/// Titres d'un média dans ses différentes langues.
class MediaTitle {
  final String? romaji;
  final String? english;
  final String? native;

  const MediaTitle({this.romaji, this.english, this.native});

  /// Meilleur titre affichable : anglais > romaji > natif > "Sans titre".
  String get preferred =>
      english ?? romaji ?? native ?? 'Sans titre';

  factory MediaTitle.fromJson(Map<String, dynamic>? json) => MediaTitle(
        romaji: json?['romaji'] as String?,
        english: json?['english'] as String?,
        native: json?['native'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'romaji': romaji,
        'english': english,
        'native': native,
      };
}

/// Un média anime avec ses métadonnées (issu d'AniList/Jikan).
class Media {
  /// ID AniList (identifiant principal).
  final int anilistId;

  /// ID MyAnimeList / Jikan (optionnel).
  final int? malId;

  final MediaTitle title;
  final AnimeFormat format;
  final ReleaseStatus status;

  /// Nombre d'épisodes connu, ou `null` si inconnu.
  final int? episodes;

  /// Durée moyenne d'un épisode en minutes, ou `null`.
  final int? durationMinutes;

  final AnimeSeason? season;
  final int? seasonYear;

  final String? coverUrl;
  final String? bannerUrl;
  final String? description;
  final List<String> genres;

  /// Score moyen 0–100 (AniList `averageScore`), ou `null`.
  final int? averageScore;

  const Media({
    required this.anilistId,
    this.malId,
    required this.title,
    this.format = AnimeFormat.unknown,
    this.status = ReleaseStatus.unknown,
    this.episodes,
    this.durationMinutes,
    this.season,
    this.seasonYear,
    this.coverUrl,
    this.bannerUrl,
    this.description,
    this.genres = const [],
    this.averageScore,
  });

  /// `true` si c'est un film (média unique, pas d'« épisode suivant »).
  bool get isMovie => format == AnimeFormat.movie;

  /// Parse un nœud `Media` de la réponse GraphQL AniList.
  factory Media.fromAniList(Map<String, dynamic> json) => Media(
        anilistId: json['id'] as int,
        malId: json['idMal'] as int?,
        title: MediaTitle.fromJson(json['title'] as Map<String, dynamic>?),
        format: animeFormatFromAniList(json['format'] as String?),
        status: ReleaseStatus.fromAniList(json['status'] as String?),
        episodes: json['episodes'] as int?,
        durationMinutes: json['duration'] as int?,
        season: AnimeSeason.fromAniList(json['season'] as String?),
        seasonYear: json['seasonYear'] as int?,
        coverUrl: (json['coverImage'] as Map<String, dynamic>?)?['large']
                as String? ??
            (json['coverImage'] as Map<String, dynamic>?)?['medium']
                as String?,
        bannerUrl: json['bannerImage'] as String?,
        description: json['description'] as String?,
        genres: (json['genres'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        averageScore: json['averageScore'] as int?,
      );

  /// Sérialisation JSON pour le cache local (round-trip avec [Media.fromJson]).
  Map<String, dynamic> toJson() => {
        'anilistId': anilistId,
        'malId': malId,
        'title': title.toJson(),
        'format': format.name,
        'status': status.name,
        'episodes': episodes,
        'durationMinutes': durationMinutes,
        'season': season?.name,
        'seasonYear': seasonYear,
        'coverUrl': coverUrl,
        'bannerUrl': bannerUrl,
        'description': description,
        'genres': genres,
        'averageScore': averageScore,
      };

  factory Media.fromJson(Map<String, dynamic> json) => Media(
        anilistId: json['anilistId'] as int,
        malId: json['malId'] as int?,
        title: MediaTitle.fromJson(json['title'] as Map<String, dynamic>?),
        format: AnimeFormat.values.byName(json['format'] as String? ?? 'unknown'),
        status: ReleaseStatus.values
            .byName(json['status'] as String? ?? 'unknown'),
        episodes: json['episodes'] as int?,
        durationMinutes: json['durationMinutes'] as int?,
        season: (json['season'] as String?) == null
            ? null
            : AnimeSeason.values.byName(json['season'] as String),
        seasonYear: json['seasonYear'] as int?,
        coverUrl: json['coverUrl'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
        description: json['description'] as String?,
        genres: (json['genres'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        averageScore: json['averageScore'] as int?,
      );
}
