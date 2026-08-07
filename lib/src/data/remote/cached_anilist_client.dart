/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Client AniList avec cache local (pattern cache-aside) + limitation de débit.
///
/// Stratégie :
/// 1. Lit le cache ([MetaCacheRepository]) pour la clé de la requête.
/// 2. Si présent et non expiré (TTL) → renvoie la valeur cachée (0 réseau).
/// 3. Sinon → appelle AniList (via [RequestQueue] pour éviter le 429), puis
///    stocke le résultat avec une date d'expiration.
///
/// TTL adaptés à la volatilité : métadonnées stables (fiches, recherche, saison,
/// relations) = long ; planning/airing = court.
library;

import 'dart:convert';

import '../../domain/models/airing_schedule.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/media.dart';
import '../../domain/models/media_relation.dart';
import '../repositories/meta_cache_repository.dart';
import 'anilist_client.dart';
import 'request_queue.dart';

/// Durées de validité par défaut du cache.
class CacheTtl {
  /// Métadonnées stables (fiches, recherche, saison, relations).
  static const Duration metadata = Duration(days: 7);

  /// Planning / prochaine diffusion (change chaque semaine).
  static const Duration airing = Duration(hours: 1);
}

/// Enveloppe cache-aside autour d'un [AniListApi] (généralement [AniListClient]).
class CachedAniListClient implements AniListApi {
  final AniListApi _inner;
  final MetaCacheRepository _cache;
  final RequestQueue _queue;

  /// Fournit l'instant courant (injecté pour testabilité déterministe).
  final DateTime Function() _now;

  /// Si `true`, ignore le cache en lecture et rafraîchit depuis le réseau
  /// (bouton « rafraîchir »). Le résultat est tout de même re-mis en cache.
  final bool forceRefresh;

  CachedAniListClient({
    required AniListApi inner,
    required MetaCacheRepository cache,
    RequestQueue? queue,
    DateTime Function()? now,
    this.forceRefresh = false,
  })  : _inner = inner,
        _cache = cache,
        _queue = queue ?? RequestQueue(),
        _now = now ?? DateTime.now;

  /// Cœur du cache-aside : lit le cache, sinon appelle [fetch] via la file et
  /// stocke le JSON sérialisé par [encode]. [decode] reconstruit l'objet.
  Future<T> _cached<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetch,
    required String Function(T) encode,
    required T Function(String) decode,
  }) async {
    final now = _now();

    if (!forceRefresh) {
      final hit = await _cache.get(key, now);
      if (hit != null) {
        try {
          return decode(hit);
        } catch (_) {
          // Cache corrompu : on ignore et on rafraîchit.
        }
      }
    }

    final fresh = await _queue.add(fetch);
    await _cache.put(key, encode(fresh), now.add(ttl));
    return fresh;
  }

  // --- Sérialisation List<Media> ---------------------------------------------

  static String _encodeMediaList(List<Media> list) =>
      jsonEncode(list.map((m) => m.toJson()).toList());

  static List<Media> _decodeMediaList(String s) =>
      (jsonDecode(s) as List<dynamic>)
          .map((e) => Media.fromJson(e as Map<String, dynamic>))
          .toList();

  // --- API AniListApi --------------------------------------------------------

  @override
  Future<List<Media>> search(String query, {int page = 1, int perPage = 20}) {
    return _cached<List<Media>>(
      key: 'search:$query:$page:$perPage',
      ttl: CacheTtl.metadata,
      fetch: () => _inner.search(query, page: page, perPage: perPage),
      encode: _encodeMediaList,
      decode: _decodeMediaList,
    );
  }

  @override
  Future<List<Media>> season(AnimeSeason season, int year,
      {int page = 1, int perPage = 50}) {
    return _cached<List<Media>>(
      // Le planning dérive de season() → TTL court pour rester frais.
      key: 'season:${season.name}:$year:$page:$perPage',
      ttl: CacheTtl.airing,
      fetch: () => _inner.season(season, year, page: page, perPage: perPage),
      encode: _encodeMediaList,
      decode: _decodeMediaList,
    );
  }

  @override
  Future<Media> mediaDetail(int anilistId) {
    return _cached<Media>(
      key: 'media:$anilistId',
      ttl: CacheTtl.metadata,
      fetch: () => _inner.mediaDetail(anilistId),
      encode: (m) => jsonEncode(m.toJson()),
      decode: (s) => Media.fromJson(jsonDecode(s) as Map<String, dynamic>),
    );
  }

  @override
  Future<List<MediaRelation>> relations(int anilistId) {
    return _cached<List<MediaRelation>>(
      key: 'relations:$anilistId',
      ttl: CacheTtl.metadata,
      fetch: () => _inner.relations(anilistId),
      encode: (list) => jsonEncode(list.map((r) => r.toJson()).toList()),
      decode: (s) => (jsonDecode(s) as List<dynamic>)
          .map((e) => MediaRelation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<AiringSchedule?> nextAiring(int anilistId) {
    return _cached<AiringSchedule?>(
      key: 'airing:$anilistId',
      ttl: CacheTtl.airing,
      fetch: () => _inner.nextAiring(anilistId),
      encode: (a) => a == null ? 'null' : jsonEncode(a.toJson()),
      decode: (s) => s == 'null'
          ? null
          : AiringSchedule.fromJson(jsonDecode(s) as Map<String, dynamic>),
    );
  }
}
