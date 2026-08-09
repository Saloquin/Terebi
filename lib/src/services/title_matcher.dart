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

    // Cache local : si on a déjà enrichi ce média, on le réutilise.
    final cached = await mediaRepo.getMedia(media.anilistId);
    if (cached != null && cached.coverUrl != null) return cached;

    // Enrichissement AniList optionnel (best-effort, non bloquant).
    final enrich = await _fetchEnrichment(animeSamaTitle);
    if (enrich != null) media = media.enrichedWith(enrich);

    await mediaRepo.upsertMedia(media);
    return media;
  }

  /// Cherche sur AniList un média dont le titre **ressemble** à [query].
  /// Retourne `null` si rien de fiable (aucun résultat, ou 1er résultat trop
  /// différent → évite le faux match). N'écrit rien : simple lecture.
  Future<Media?> _fetchEnrichment(String query) async {
    try {
      final results = await anilist.search(query);
      for (final m in results) {
        final candidate = m.title.english ?? m.title.romaji ?? m.title.native;
        if (candidate != null && titlesSimilar(query, candidate)) {
          return m;
        }
      }
    } catch (_) {
      // AniList indisponible / rate-limité → pas d'enrichissement.
    }
    return null;
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
