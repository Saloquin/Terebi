/// Domaine applicatif — catalogue anime-sama en cache-first.
///
/// La DB est un CACHE : [watchDetail] emet immediatement l'etat DB (meme
/// perime) et declenche, si le TTL est depasse, une revalidation en tache de
/// fond (scrape `catalogue-detail`) qui reecrit la DB. Le stream Drift
/// [MediaRepository.watchMedia] propage alors la mise a jour a l'UI.
library;

import 'dart:async';

import '../data/repositories/media_repository.dart';
import '../domain/logic/anime_id.dart';
import '../domain/models/media.dart';
import 'stream_resolver.dart';

/// Recupere le detail enrichi d'un slug (reseau en prod, stub en test).
typedef DetailFetcher = Future<AnimeSamaDetail?> Function(String slug);

class AnimeSamaCatalogService {
  final MediaRepository mediaRepo;
  final DetailFetcher fetchDetail;

  /// Duree de fraicheur du cache : au-dela, [watchDetail] revalide en fond.
  final Duration ttl;

  const AnimeSamaCatalogService({
    required this.mediaRepo,
    required this.fetchDetail,
    this.ttl = const Duration(hours: 12),
  });

  /// Stream du media pour [slug] : etat DB immediat + revalidation background
  /// si le cache est absent ou perime.
  Stream<Media?> watchDetail(String slug) {
    final id = animeSamaIdForSlug(slug);
    unawaited(_maybeRevalidate(slug, id));
    return mediaRepo.watchMedia(id);
  }

  /// Force un scrape `catalogue-detail` et ecrit le resultat en DB.
  Future<void> revalidate(String slug) async {
    final detail = await fetchDetail(slug);
    if (detail == null) return;
    final existing = await mediaRepo.getMedia(animeSamaIdForSlug(slug));
    final media = Media.fromAnimeSama(
      slug: slug,
      title: detail.title.isNotEmpty
          ? detail.title
          : (existing?.animeSamaTitle ?? slug),
      synopsis: detail.synopsis ?? existing?.description,
      genres: detail.genres.isNotEmpty
          ? detail.genres
          : (existing?.genres ?? const []),
      coverUrl: detail.cover ?? existing?.coverUrl,
      bannerUrl: detail.banner ?? existing?.bannerUrl,
    );
    await mediaRepo.upsertMedia(media);
  }

  /// Revalide si le cache est absent ou plus vieux que [ttl] (fire-and-forget).
  Future<void> _maybeRevalidate(String slug, int id) async {
    final existing = await mediaRepo.getMedia(id);
    final bool stale;
    if (existing == null || ttl == Duration.zero) {
      stale = true;
    } else {
      final updatedAt = await mediaRepo.updatedAtOf(id);
      stale = DateTime.now().toUtc().difference(updatedAt) > ttl;
    }
    if (stale) {
      unawaited(revalidate(slug));
    }
  }
}
