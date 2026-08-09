/// Résout un titre anime-sama en [Media] exploitable.
///
/// **anime-sama est la source de vérité** : l'identité d'un anime dérive TOUJOURS
/// de son titre anime-sama ([animeSamaIdFor], id négatif stable), jamais de
/// l'`anilistId`. AniList n'est qu'un **enrichissement optionnel** (image +
/// description) appliqué UNIQUEMENT si le titre trouvé ressemble vraiment au
/// titre cherché ([titlesSimilar]). Un mauvais match AniList (ex.
/// « demon slayer » → « onigiri ») n'affecte donc jamais l'identité ni la
/// bibliothèque : au pire, il n'y a pas d'image/description.
library;

import '../data/remote/anilist_client.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/models/media.dart';

class TitleMatcher {
  final AniListApi anilist;
  final SettingsRepository settings;
  final MediaRepository mediaRepo;

  const TitleMatcher({
    required this.anilist,
    required this.settings,
    required this.mediaRepo,
  });

  /// Résout un titre anime-sama en [Media] — **jamais null**.
  ///
  /// - Identité = `Media.fromAnimeSama(title)` (id négatif stable).
  /// - Enrichissement AniList (cover/description) seulement si un résultat de
  ///   recherche a un titre **similaire** au titre cherché.
  Future<Media> resolve(String animeSamaTitle) async {
    // Base : le média anime-sama fait foi (identité stable).
    var media = Media.fromAnimeSama(title: animeSamaTitle);

    // Cache local : si ce média a déjà été résolu AVEC image, on le réutilise.
    // Sans image, on ne réessaie que si l'échec précédent était RÉSEAU (pour
    // récupérer l'image ratée à cause d'un 429), pas si « pas de match ».
    final cached = await mediaRepo.getMedia(media.anilistId);
    if (cached != null && cached.animeSamaTitle != null) {
      if (cached.coverUrl != null) return cached; // déjà enrichi
      final failedNoMatch = await _isMarkedNoMatch(animeSamaTitle);
      if (failedNoMatch) return cached; // rien à gagner à réessayer
      // sinon : échec réseau précédent → on retente l'enrichissement ci-dessous
    }

    // Enrichissement AniList (best-effort). networkFailed distingue
    // « pas de résultat fiable » (définitif) d'un « échec réseau » (temporaire).
    final (enrich, networkFailed) = await _fetchEnrichment(animeSamaTitle);
    if (enrich != null) media = media.enrichedWith(enrich);

    await mediaRepo.upsertMedia(media);
    // Mémorise « pas de match » seulement si la recherche a abouti sans trouver
    // (pas d'échec réseau) → évite de réessayer inutilement plus tard.
    await _markNoMatch(animeSamaTitle, enrich == null && !networkFailed);
    return media;
  }

  static const _noMatchPrefix = 'anime_sama_nomatch:';

  Future<bool> _isMarkedNoMatch(String title) async {
    final v = await settings.get(_noMatchPrefix + normalizeAnimeTitle(title));
    return v == '1';
  }

  Future<void> _markNoMatch(String title, bool noMatch) async {
    final key = _noMatchPrefix + normalizeAnimeTitle(title);
    if (noMatch) {
      await settings.set(key, '1');
    } else {
      await settings.delete(key); // match trouvé ou échec réseau → réessai permis
    }
  }

  /// Cherche sur AniList un média dont un des titres (anglais/romaji/natif)
  /// **ressemble** à [query]. Retourne (media|null, networkFailed) :
  /// - (media, false) : match fiable trouvé ;
  /// - (null, false)  : recherche OK mais aucun résultat similaire (définitif) ;
  /// - (null, true)   : échec réseau / rate-limit (à retenter plus tard).
  Future<(Media?, bool)> _fetchEnrichment(String query) async {
    try {
      final results = await anilist.search(query);
      for (final m in results) {
        final candidates = [
          m.title.english,
          m.title.romaji,
          m.title.native,
        ];
        for (final c in candidates) {
          if (c != null && titlesSimilar(query, c)) {
            return (m, false);
          }
        }
      }
      return (null, false); // recherche aboutie, pas de match
    } catch (_) {
      return (null, true); // AniList indisponible / rate-limité
    }
  }

  /// Recherche AniList directe (1er résultat), sans garde-fou. Conservé pour un
  /// éventuel usage où l'identité AniList est explicitement voulue. Cache le
  /// mapping titre→anilistId dans les settings.
  Future<Media?> match(String title) async {
    final key = _cacheKey(title);
    final cachedId = await settings.get(key);
    if (cachedId != null) {
      final id = int.tryParse(cachedId);
      if (id != null) {
        final local = await mediaRepo.getMedia(id);
        if (local != null) return local;
        try {
          return await anilist.mediaDetail(id);
        } catch (_) {/* recherche fraîche */}
      }
    }
    final results = await anilist.search(title);
    if (results.isEmpty) return null;
    final media = results.first;
    await settings.set(key, '${media.anilistId}');
    await mediaRepo.upsertMedia(media);
    return media;
  }

  String _cacheKey(String title) =>
      SettingsKeys.animeSamaAniListFor(normalizeAnimeTitle(title));
}
