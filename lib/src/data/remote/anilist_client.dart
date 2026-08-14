/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Client GraphQL AniList avec gestion d'erreurs et injection de dépendance HTTP.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/models/airing_schedule.dart';
import '../../domain/models/anime_format.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/media.dart';
import '../../domain/models/media_relation.dart';

/// Construit un [Media] depuis un objet JSON AniList (fragment `_kMediaFragment`).
Media _mediaFromAniListJson(Map<String, dynamic> e) {
  final nae = e['nextAiringEpisode'] as Map<String, dynamic>?;
  return Media(
    anilistId: e['id'] as int,
    malId: e['idMal'] as int?,
    title: MediaTitle.fromJson(e['title'] as Map<String, dynamic>?),
    format: animeFormatFromAniList(e['format'] as String?),
    status: ReleaseStatus.fromAniList(e['status'] as String?),
    episodes: e['episodes'] as int?,
    durationMinutes: e['duration'] as int?,
    season: AnimeSeason.fromAniList(e['season'] as String?),
    seasonYear: e['seasonYear'] as int?,
    coverUrl: (e['coverImage'] as Map<String, dynamic>?)?['large'] as String?,
    bannerUrl: e['bannerImage'] as String?,
    description: e['description'] as String?,
    genres: (e['genres'] as List<dynamic>?)?.cast<String>() ?? const [],
    averageScore: e['averageScore'] as int?,
    nextAiringAt: nae != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (nae['airingAt'] as int) * 1000,
            isUtc: true,
          )
        : null,
    nextAiringEpisode: nae?['episode'] as int?,
  );
}

/// Endpoint GraphQL AniList.
const _kEndpoint = 'https://graphql.anilist.co';

/// Fragment GraphQL réutilisé pour les champs média.
const _kMediaFragment = '''
  id
  idMal
  title { romaji english native }
  format
  status
  episodes
  duration
  season
  seasonYear
  coverImage { large medium }
  bannerImage
  description
  genres
  averageScore
  nextAiringEpisode { airingAt episode }
''';

/// Exception levée lors d'une erreur AniList (HTTP ou erreur GraphQL).
class AniListException implements Exception {
  final String message;
  final int? statusCode;

  const AniListException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'AniListException[$statusCode]: $message'
      : 'AniListException: $message';
}

/// Interface commune des sources de données AniList (client direct ou caché).
///
/// Permet de substituer un [CachedAniListClient] au [AniListClient] de façon
/// transparente pour l'UI.
abstract interface class AniListApi {
  Future<List<Media>> search(String query, {int page, int perPage});
  Future<List<Media>> season(AnimeSeason season, int year,
      {int page, int perPage});
  Future<Media> mediaDetail(int anilistId);
  Future<List<MediaRelation>> relations(int anilistId);
  Future<AiringSchedule?> nextAiring(int anilistId);

  /// Tendances du moment (communauté AniList, sort TRENDING_DESC).
  Future<List<Media>> trending({int page, int perPage});

  /// Animes les plus populaires (communauté AniList, sort POPULARITY_DESC).
  Future<List<Media>> popular({int page, int perPage});

  /// Animes d'un [genre] donné, triés par score décroissant (découverte).
  Future<List<Media>> byGenre(String genre, {int page, int perPage});
}

/// Client AniList GraphQL.
///
/// Injectez un [http.Client] personnalisé (ex. [MockClient]) pour les tests.
/// Par défaut, un [http.Client()] réel est utilisé.
class AniListClient implements AniListApi {
  final http.Client _http;

  AniListClient({http.Client? client}) : _http = client ?? http.Client();

  /// Envoie une requête GraphQL et retourne le corps décodé.
  ///
  /// Lance [AniListException] si le statut HTTP != 200 ou si la réponse
  /// contient des erreurs GraphQL.
  Future<Map<String, dynamic>> _query(
    String query, [
    Map<String, dynamic>? variables,
  ]) async {
    final response = await _http.post(
      Uri.parse(_kEndpoint),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'query': query, if (variables != null) 'variables': variables}),
    );

    if (response.statusCode != 200) {
      throw AniListException(
        'Réponse HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = body['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final msg = (errors.first as Map<String, dynamic>)['message'] as String? ?? 'Erreur GraphQL';
      throw AniListException(msg);
    }

    return body['data'] as Map<String, dynamic>;
  }

  /// Recherche des médias par titre.
  ///
  /// Retourne jusqu'à [perPage] résultats pour la [page] donnée.
  @override
  Future<List<Media>> search(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async {
    const gql = '''
      query(\$q: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(search: \$q, type: ANIME, isAdult: false) {
            $_kMediaFragment
          }
        }
      }
    ''';
    final data = await _query(gql, {'q': query, 'page': page, 'perPage': perPage});
    final mediaList = (data['Page']['media'] as List<dynamic>);
    return mediaList
        .map((e) => _mediaFromAniListJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Récupère les animes d'une saison donnée, triés par popularité décroissante.
  @override
  Future<List<Media>> season(
    AnimeSeason season,
    int year, {
    int page = 1,
    int perPage = 50,
  }) async {
    const gql = '''
      query(\$season: MediaSeason, \$year: Int, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(season: \$season, seasonYear: \$year, type: ANIME, isAdult: false,
                sort: POPULARITY_DESC) {
            $_kMediaFragment
          }
        }
      }
    ''';
    final data = await _query(gql, {
      'season': season.anilist,
      'year': year,
      'page': page,
      'perPage': perPage,
    });
    final mediaList = data['Page']['media'] as List<dynamic>;
    return mediaList
        .map((e) => _mediaFromAniListJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Liste de médias triés par un critère AniList (`sort`). Factorise
  /// trending/popular (mêmes requête et parsing, seul le tri change).
  Future<List<Media>> _mediaBySort(String sort, int page, int perPage) async {
    final gql = '''
      query(\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, isAdult: false, sort: $sort) {
            $_kMediaFragment
          }
        }
      }
    ''';
    final data = await _query(gql, {'page': page, 'perPage': perPage});
    final mediaList = data['Page']['media'] as List<dynamic>;
    return mediaList
        .map((e) => _mediaFromAniListJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Media>> trending({int page = 1, int perPage = 20}) =>
      _mediaBySort('TRENDING_DESC', page, perPage);

  @override
  Future<List<Media>> popular({int page = 1, int perPage = 20}) =>
      _mediaBySort('POPULARITY_DESC', page, perPage);

  /// Animes d'un [genre] donné, triés par score décroissant (découverte).
  @override
  Future<List<Media>> byGenre(String genre,
      {int page = 1, int perPage = 20}) async {
    const gql = '''
      query(\$genre: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, isAdult: false, genre_in: [\$genre],
                sort: SCORE_DESC) {
            $_kMediaFragment
          }
        }
      }
    ''';
    final data =
        await _query(gql, {'genre': genre, 'page': page, 'perPage': perPage});
    final mediaList = data['Page']['media'] as List<dynamic>;
    return mediaList
        .map((e) => _mediaFromAniListJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Récupère le détail complet d'un média par son ID AniList.
  @override
  Future<Media> mediaDetail(int anilistId) async {
    const gql = '''
      query(\$id: Int) {
        Media(id: \$id, type: ANIME) {
          $_kMediaFragment
        }
      }
    ''';
    final data = await _query(gql, {'id': anilistId});
    return _mediaFromAniListJson(data['Media'] as Map<String, dynamic>);
  }

  /// Récupère les relations d'un média (suites, préquelles, spin-offs…).
  @override
  Future<List<MediaRelation>> relations(int anilistId) async {
    const gql = '''
      query(\$id: Int) {
        Media(id: \$id, type: ANIME) {
          relations {
            edges {
              relationType
              node { id }
            }
          }
        }
      }
    ''';
    final data = await _query(gql, {'id': anilistId});
    final edges = (data['Media']['relations']['edges'] as List<dynamic>);
    return edges
        .map((e) {
          final edge = e as Map<String, dynamic>;
          final relatedId = (edge['node'] as Map<String, dynamic>)['id'] as int;
          final type = RelationType.fromAniList(edge['relationType'] as String?);
          return MediaRelation(
            mediaId: anilistId,
            relatedMediaId: relatedId,
            type: type,
          );
        })
        .toList();
  }

  /// Récupère le prochain épisode à diffuser pour un média.
  ///
  /// Retourne `null` si aucun épisode n'est planifié (média terminé ou film).
  @override
  Future<AiringSchedule?> nextAiring(int anilistId) async {
    const gql = '''
      query(\$id: Int) {
        Media(id: \$id, type: ANIME) {
          nextAiringEpisode { airingAt episode }
        }
      }
    ''';
    final data = await _query(gql, {'id': anilistId});
    final nae = data['Media']['nextAiringEpisode'] as Map<String, dynamic>?;
    if (nae == null) return null;
    return AiringSchedule.fromAniList(nae, mediaId: anilistId);
  }
}
