/// Rematch d'un titre anime-sama vers une entrée AniList (pour obtenir un
/// [Media] riche : synopsis, note, image, et surtout un `anilistId` exploitable
/// par la fiche / le lecteur / la progression).
///
/// anime-sama ne fournit qu'un titre + une URL catalogue ; le reste de l'app est
/// indexé par `anilistId`. On recherche donc le titre sur AniList et on prend le
/// **1er résultat** (décision produit validée : auto-match, sans garde-fou).
///
/// Le mapping titre→anilistId est mémorisé dans les settings pour éviter de
/// relancer une recherche AniList (et limiter les 429).
library;

import '../data/remote/anilist_client.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/models/media.dart';

/// Résout un titre anime-sama en [Media] AniList (1er résultat), avec cache.
class TitleMatcher {
  final AniListApi anilist;
  final SettingsRepository settings;
  final MediaRepository mediaRepo;

  const TitleMatcher({
    required this.anilist,
    required this.settings,
    required this.mediaRepo,
  });

  /// Retourne le [Media] AniList correspondant à [title], ou `null` si aucun
  /// résultat. Utilise le cache titre→anilistId quand disponible.
  Future<Media?> match(String title) async {
    final key = _cacheKey(title);

    // 1) Cache : anilistId déjà connu pour ce titre ?
    final cachedId = await settings.get(key);
    if (cachedId != null) {
      final id = int.tryParse(cachedId);
      if (id != null) {
        // Média persisté localement en priorité (évite un appel réseau).
        final local = await mediaRepo.getMedia(id);
        if (local != null) return local;
        try {
          return await anilist.mediaDetail(id);
        } catch (_) {
          // Cache périmé/injoignable : on retombe sur une recherche fraîche.
        }
      }
    }

    // 2) Recherche AniList : 1er résultat.
    final results = await anilist.search(title);
    if (results.isEmpty) return null;
    final media = results.first;

    // Mémorise le mapping + les métadonnées (pour la biblio hors-ligne).
    await settings.set(key, '${media.anilistId}');
    await mediaRepo.upsertMedia(media);
    return media;
  }

  /// Clé de cache stable dérivée du titre normalisé.
  String _cacheKey(String title) {
    final norm = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return SettingsKeys.animeSamaAniListFor(norm);
  }

  /// Résout un titre anime-sama en [Media] exploitable — **jamais null**.
  ///
  /// anime-sama est la source de vérité : si AniList reconnaît le titre, on
  /// enrichit avec ses métadonnées (image/description) ; sinon on fabrique un
  /// [Media.fromAnimeSama] avec un id négatif stable. Dans les deux cas le
  /// média porte [animeSamaTitle] et est persisté localement.
  Future<Media> resolve(String animeSamaTitle) async {
    Media? matched;
    try {
      matched = await match(animeSamaTitle);
    } catch (_) {
      matched = null; // AniList indisponible → fallback anime-sama.
    }

    final media = (matched != null)
        ? matched.withAnimeSamaTitle(animeSamaTitle)
        : Media.fromAnimeSama(title: animeSamaTitle);

    // Persiste (met à jour animeSamaTitle / crée l'entrée fallback).
    await mediaRepo.upsertMedia(media);
    return media;
  }
}
