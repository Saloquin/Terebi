/// Cache persistant « cache-first » pour les saisons et épisodes anime-sama —
/// AUCUN import de package:flutter.
///
/// Principe métier :
///  1. Une saison ou un épisode déjà découvert ne disparaît pas : si un nouveau
///     scraping échoue, renvoie moins d'éléments (régression HTML/site) ou est
///     vide, on conserve les données déjà en base (`mergeCachedAndFresh*`).
///  2. À l'ouverture d'une fiche ou du lecteur, la base locale (`MetaCache`)
///     est servie immédiatement (0 ms, fonctionne hors-ligne). Si l'entrée est
///     absente ou périmée (`softTtl`), une revalidation silencieuse met à jour
///     la base ; le stream Drift ré-émet alors automatiquement vers l'UI.
library;

import 'dart:async';
import 'dart:convert';

import '../data/repositories/meta_cache_repository.dart';
import 'stream_resolver.dart';

typedef FetchSeasonsCallback = Future<List<AnimeSamaSeason>> Function(
  String title,
  PlaybackLanguage language,
);

typedef FetchEpisodesCallback = Future<List<int>> Function(
  String title,
  int seasonIndex,
  PlaybackLanguage language,
);

/// Fusion monotone des saisons : préserve l'historique en base contre un
/// scraping partiel/dégradé, tout en intégrant les nouvelles saisons et noms
/// corrigés lorsque la réponse fraîche est au moins aussi complète.
List<AnimeSamaSeason> mergeCachedAndFreshSeasons(
  List<AnimeSamaSeason> cached,
  List<AnimeSamaSeason> fresh,
) {
  if (fresh.isEmpty) return cached;
  if (cached.isEmpty) return fresh;

  // La réponse fraîche contient autant ou plus de saisons : elle est complète
  // (nouvelle saison sortie, ou auto-réparation après une ancienne capture
  // partielle où des index avaient sauté).
  if (fresh.length >= cached.length) return fresh;

  // Sinon `fresh` est strictement plus court qu'en base : si tous ses titres
  // sont déjà connus du cache, il s'agit d'un scraping tronqué ou incomplet
  // (ex. une saison sautée au milieu qui décalerait les index suivants) →
  // on garde le cache intact pour éviter toute corruption d'index.
  final cachedNames = {
    for (final s in cached) s.name.trim().toLowerCase(),
  };
  final allFreshAlreadyCached = fresh.every(
    (s) => cachedNames.contains(s.name.trim().toLowerCase()),
  );
  if (allFreshAlreadyCached) return cached;

  // Cas marginal d'un nom réellement inédit dans une réponse plus courte :
  // fusion par index afin de ne perdre aucune saison existante.
  final byIndex = <int, AnimeSamaSeason>{
    for (final s in cached) s.index: s,
  };
  for (final s in fresh) {
    byIndex[s.index] = s;
  }
  return byIndex.values.toList()..sort((a, b) => a.index.compareTo(b.index));
}

/// Fusion monotone des numéros d'épisodes : union triée sans perte en cas de
/// réponse partielle ou vide.
List<int> mergeCachedAndFreshEpisodes(
  List<int> cached,
  List<int> fresh,
) {
  if (fresh.isEmpty) return cached;
  if (cached.isEmpty) return fresh;
  final merged = <int>{...cached, ...fresh}.toList()..sort();
  return merged;
}

class AnimeSamaSeasonCacheService {
  static const Duration defaultSoftTtl = Duration(hours: 6);
  static const Duration defaultRetention = Duration(days: 365);

  final MetaCacheRepository _cache;
  final FetchSeasonsCallback _fetchSeasons;
  final FetchEpisodesCallback _fetchEpisodes;
  final Duration softTtl;
  final Duration retention;
  final DateTime Function() _now;

  final Map<String, Future<List<AnimeSamaSeason>>> _inFlightSeasons = {};
  final Map<String, Future<List<int>>> _inFlightEpisodes = {};

  AnimeSamaSeasonCacheService({
    required MetaCacheRepository cache,
    required FetchSeasonsCallback fetchSeasons,
    required FetchEpisodesCallback fetchEpisodes,
    this.softTtl = defaultSoftTtl,
    this.retention = defaultRetention,
    DateTime Function()? now,
  })  : _cache = cache,
        _fetchSeasons = fetchSeasons,
        _fetchEpisodes = fetchEpisodes,
        _now = now ?? DateTime.now;

  static String seasonsCacheKey(String title) =>
      'as_seasons:v1:${title.trim().toLowerCase()}';

  static String episodesCacheKey(
    String title,
    int seasonIndex, [
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  ]) =>
      'as_eps:v1:${language.name}:${title.trim().toLowerCase()}:s$seasonIndex';

  /// Lit les saisons persistées en base (ou `null` si absentes/corrompues).
  Future<List<AnimeSamaSeason>?> getCachedSeasons(String title) async {
    final entry = await _cache.getEntry(seasonsCacheKey(title));
    final decoded = _decodeSeasons(entry?.payload);
    if (decoded == null || decoded.value.isEmpty) return null;
    return decoded.value;
  }

  /// Lit les épisodes persistés en base (ou `null` si absents/corrompus).
  Future<List<int>?> getCachedEpisodes(
    String title,
    int seasonIndex, {
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final entry =
        await _cache.getEntry(episodesCacheKey(title, seasonIndex, language));
    final decoded = _decodeEpisodes(entry?.payload);
    if (decoded == null || decoded.value.isEmpty) return null;
    return decoded.value;
  }

  /// Flux cache-first des saisons pour [title].
  Stream<List<AnimeSamaSeason>> watchSeasons(
    String title, {
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) {
    return _watchCached<List<AnimeSamaSeason>>(
      key: seasonsCacheKey(title),
      decode: _decodeSeasons,
      equals: _seasonsEqual,
      isEmpty: (list) => list.isEmpty,
      refresh: () => refreshSeasons(title, language: language),
    );
  }

  /// Flux cache-first des épisodes pour `(title, seasonIndex)`.
  Stream<List<int>> watchEpisodes(
    String title,
    int seasonIndex, {
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) {
    return _watchCached<List<int>>(
      key: episodesCacheKey(title, seasonIndex, language),
      decode: _decodeEpisodes,
      equals: _intsEqual,
      isEmpty: (list) => list.isEmpty,
      refresh: () => refreshEpisodes(title, seasonIndex, language: language),
    );
  }

  /// Force une récupération réseau des saisons, fusionne de façon monotone
  /// avec la base locale, puis persiste si non vide. Dédupliqué si déjà en vol.
  Future<List<AnimeSamaSeason>> refreshSeasons(
    String title, {
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final key = seasonsCacheKey(title);
    final existing = _inFlightSeasons[key];
    if (existing != null) return existing;

    final future = _doRefreshSeasons(key, title, language);
    _inFlightSeasons[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightSeasons[key], future)) {
        _inFlightSeasons.remove(key);
      }
    }
  }

  Future<List<AnimeSamaSeason>> _doRefreshSeasons(
    String key,
    String title,
    PlaybackLanguage language,
  ) async {
    final fresh = await _fetchSeasons(title, language);
    final cached = await getCachedSeasons(title) ?? const <AnimeSamaSeason>[];
    final merged = mergeCachedAndFreshSeasons(cached, fresh);
    if (merged.isNotEmpty) {
      final now = _now();
      await _cache.put(
        key,
        jsonEncode({
          'v': 1,
          'updatedAtMs': now.millisecondsSinceEpoch,
          'seasons': [
            for (final s in merged) {'index': s.index, 'name': s.name},
          ],
        }),
        now.add(retention),
      );
    }
    return merged;
  }

  /// Force une récupération réseau des épisodes, fusionne de façon monotone
  /// avec la base locale, puis persiste si non vide. Dédupliqué si déjà en vol.
  Future<List<int>> refreshEpisodes(
    String title,
    int seasonIndex, {
    PlaybackLanguage language = PlaybackLanguage.vostfr,
  }) async {
    final key = episodesCacheKey(title, seasonIndex, language);
    final existing = _inFlightEpisodes[key];
    if (existing != null) return existing;

    final future = _doRefreshEpisodes(key, title, seasonIndex, language);
    _inFlightEpisodes[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightEpisodes[key], future)) {
        _inFlightEpisodes.remove(key);
      }
    }
  }

  Future<List<int>> _doRefreshEpisodes(
    String key,
    String title,
    int seasonIndex,
    PlaybackLanguage language,
  ) async {
    final fresh = await _fetchEpisodes(title, seasonIndex, language);
    final cached = await getCachedEpisodes(
          title,
          seasonIndex,
          language: language,
        ) ??
        const <int>[];
    final merged = mergeCachedAndFreshEpisodes(cached, fresh);
    if (merged.isNotEmpty) {
      final now = _now();
      await _cache.put(
        key,
        jsonEncode({
          'v': 1,
          'updatedAtMs': now.millisecondsSinceEpoch,
          'episodes': merged,
        }),
        now.add(retention),
      );
    }
    return merged;
  }

  Stream<T> _watchCached<T>({
    required String key,
    required ({T value, DateTime updatedAt})? Function(String? payload) decode,
    required bool Function(T a, T b) equals,
    required bool Function(T) isEmpty,
    required Future<T> Function() refresh,
  }) {
    final controller = StreamController<T>();
    StreamSubscription<String?>? sub;
    T? lastEmitted;
    var hasEmitted = false;
    var refreshTriggered = false;

    void emitIfChanged(T value) {
      if (controller.isClosed) return;
      if (hasEmitted && equals(lastEmitted as T, value)) return;
      hasEmitted = true;
      lastEmitted = value;
      controller.add(value);
    }

    Future<void> triggerRefresh({required bool hasCached}) async {
      try {
        final fresh = await refresh();
        if (!hasCached && !hasEmitted) {
          emitIfChanged(fresh);
        }
      } catch (e, st) {
        if (!hasCached && !hasEmitted && !controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    controller.onListen = () {
      sub = _cache.watchPayload(key).listen(
        (payload) {
          final decoded = decode(payload);
          if (decoded != null && !isEmpty(decoded.value)) {
            emitIfChanged(decoded.value);
            if (!refreshTriggered && _isStale(decoded.updatedAt)) {
              refreshTriggered = true;
              unawaited(triggerRefresh(hasCached: true));
            }
          } else if (!refreshTriggered) {
            refreshTriggered = true;
            unawaited(triggerRefresh(hasCached: false));
          }
        },
        onError: (Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
        },
      );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  bool _isStale(DateTime updatedAt) =>
      _now().difference(updatedAt) >= softTtl;

  ({List<AnimeSamaSeason> value, DateTime updatedAt})? _decodeSeasons(
    String? raw,
  ) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final ms = map['updatedAtMs'];
      final list = map['seasons'];
      if (ms is! int || list is! List) return null;
      final seasons = <AnimeSamaSeason>[
        for (final item in list)
          if (item is Map && item['index'] is int && item['name'] is String)
            AnimeSamaSeason(
              index: item['index'] as int,
              name: item['name'] as String,
            ),
      ];
      return (
        value: seasons,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      );
    } catch (_) {
      return null;
    }
  }

  ({List<int> value, DateTime updatedAt})? _decodeEpisodes(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final ms = map['updatedAtMs'];
      final list = map['episodes'];
      if (ms is! int || list is! List) return null;
      final episodes = <int>[
        for (final e in list)
          if (e is num) e.toInt(),
      ];
      return (
        value: episodes,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      );
    } catch (_) {
      return null;
    }
  }

  static bool _seasonsEqual(List<AnimeSamaSeason> a, List<AnimeSamaSeason> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _intsEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
