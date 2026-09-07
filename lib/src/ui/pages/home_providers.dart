/// Providers partagés de la page d'accueil.
///
/// Extraits de home_page.dart pour être réutilisables par HomepageTv
/// (et tout autre consommateur qui aurait besoin des mêmes données).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/logic/effective_status_service.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart' show AnimeSamaCatalogueItem;

// ---------------------------------------------------------------------------
// Providers de rangées
// ---------------------------------------------------------------------------

/// Ids des animes TERMINÉS (statut completed). Sert à les exclure des rangées
/// « Regardé récemment » et « Continuer à regarder » (un anime fini n'est ni à
/// reprendre ni en cours). Réactif via le stream du repository de listes.
final completedIdsProvider = StreamProvider<Set<int>>((ref) {
  return ref
      .watch(listRepositoryProvider)
      .watchEntriesByStatus(ListStatus.completed)
      .map((entries) => entries.map((e) => e.mediaId).toSet());
});

/// « Continuer à regarder » : médias dont le statut EFFECTIF est « en cours »
/// (progression > 0 et non figé/terminé), triés du plus récemment mis à jour au
/// plus ancien, résolus en [Media] (cache local). Réactif (stream).
///
/// IMPORTANT : `current` n'est JAMAIS stocké en base — c'est un statut DÉRIVÉ
/// (cf. [effectiveStatus]). On reproduit donc la sémantique de la bibliothèque
/// (watchAllEntries + effectiveStatus + hasAnyProgress) au lieu de filtrer sur
/// la colonne `status`, qui ne contient jamais `current`.
final continueWatchingProvider = FutureProvider<List<Media>>((ref) async {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  // Dérive de effectiveEntriesProvider (réactif aux entrées ET à la progression
  // par saison) : marquer un épisode OU une saison rafraîchit la rangée.
  final entries = await ref.watch(effectiveEntriesProvider.future);
  final current = [
    for (final e in entries)
      if (e.status == ListStatus.current)
        (updatedAt: e.entry.updatedAt, mediaId: e.entry.mediaId),
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final result = <Media>[];
  for (final c in current) {
    final m = await mediaRepo.getMedia(c.mediaId);
    if (m != null) result.add(m);
  }
  return result;
});

/// « Sortis du moment » : planning anime-sama de la semaine, résolu en Media via
/// le slug (cache DB si dispo, sinon carte minimale). Best-effort.
final recentlyReleasedProvider = FutureProvider<List<Media>>((ref) async {
  try {
    final items = await ref.watch(animeSamaPlanningProvider.future);
    final result = <Media>[];
    final seen = <int>{};
    for (final it in items) {
      final slug = it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);
      if (slug.isEmpty) continue;
      final id = animeSamaIdForSlug(slug);
      if (!seen.add(id)) continue;
      final cached = await ref.watch(mediaRepositoryProvider).getMedia(id);
      result.add(cached ?? Media.fromAnimeSama(slug: slug, title: it.title));
    }
    return result;
  } catch (_) {
    return const [];
  }
});

/// Convertit une liste d'items catalogue anime-sama en Media (cache-first).
///
/// L'ordre est MÉLANGÉ (aléatoire) : les rangées de découverte (classiques, par
/// genre, « Ça pourrait vous plaire ») évitent ainsi d'afficher toujours les
/// mêmes animes en tête (le catalogue anime-sama est trié alphabétiquement).
/// Re-mélangé à chaque calcul du provider. N'affecte PAS les rangées « Continuer
/// à regarder » / « Regardé récemment » / « Sortis du moment » (elles n'utilisent
/// pas cette fonction et gardent leur ordre chronologique).
Future<List<Media>> itemsToMedia(
    Ref ref, List<AnimeSamaCatalogueItem> items) async {
  final repo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  final seen = <int>{};
  for (final it in items) {
    final slug = it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);
    if (slug.isEmpty) continue;
    final id = animeSamaIdForSlug(slug);
    if (!seen.add(id)) continue;
    final cached = await repo.getMedia(id);
    result.add(cached ??
        Media.fromAnimeSama(
            slug: slug,
            title: it.title,
            coverUrl: it.cover,
            genres: it.genres));
  }
  result.shuffle();
  return result;
}

/// « Les classiques » (home anime-sama).
final classicsProvider = FutureProvider<List<Media>>((ref) async {
  final home = await ref.watch(animeSamaHomeProvider.future);
  return itemsToMedia(ref, home.classics);
});

/// Recommandations par genre (catalogue anime-sama).
final byGenreProvider =
    FutureProvider.family<List<Media>, String>((ref, genre) async {
  final items = await ref.watch(animeSamaByGenreProvider(genre).future);
  return itemsToMedia(ref, items);
});

/// Genres favoris de l'utilisateur, agrégés depuis les animes TERMINÉS et EN
/// COURS de sa bibliothèque. Chaque anime compte une fois par genre. Tri par
/// occurrence décroissante ; à départage égal, ordre alphabétique pour un
/// affichage stable. Retourne TOUS les genres concernés.
///
/// IMPORTANT : on filtre sur le statut EFFECTIF (cf. [effectiveStatus]), pas sur
/// `e.status` : « en cours » (current) n'est JAMAIS stocké, il est dérivé de la
/// progression. Filtrer la colonne `status` ignorerait tous les animes en cours
/// de visionnage — soit l'essentiel de ce que l'utilisateur regarde — et
/// fausserait le tri des rangées de genre.
final watchedGenresProvider = FutureProvider<List<String>>((ref) async {
  final entries = await ref.watch(listRepositoryProvider).getAllEntries();
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final seasonProgress = ref.watch(seasonProgressRepositoryProvider);
  const kept = {
    ListStatus.completed,
    ListStatus.current,
    ListStatus.repeating,
  };
  final counts = <String, int>{};
  for (final e in entries) {
    final hasProgress =
        e.progress > 0 || await seasonProgress.hasAnyProgress(e.mediaId);
    final eff = effectiveStatus(entry: e, hasProgress: hasProgress);
    if (eff == null || !kept.contains(eff)) continue;
    final genres = (await mediaRepo.getMedia(e.mediaId))?.genres ?? const [];
    for (final g in genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return sorted;
});

/// Ensemble des ids déjà présents dans la bibliothèque (toute entrée de liste).
/// Sert à EXCLURE ces animes des rangées de découverte.
final libraryFilterProvider =
    FutureProvider<({Set<int> ids, Set<String> titles})>((ref) async {
  final entries = await ref.watch(listRepositoryProvider).getAllEntries();
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final ids = <int>{};
  final titles = <String>{};
  for (final e in entries) {
    ids.add(e.mediaId);
    final m = await mediaRepo.getMedia(e.mediaId);
    if (m != null) {
      titles.add(normalizeAnimeTitle(m.title.preferred));
      if (m.animeSamaTitle != null) titles.add(normalizeAnimeTitle(m.animeSamaTitle!));
    }
  }
  return (ids: ids, titles: titles);
});

/// « Regarde recemment » : les derniers animes LANCES (historique recent, ordre
/// chronologique inverse), dedupliques par mediaId, en EXCLUANT les animes
/// termines. Reactif (stream) : se met a jour a chaque lancement de lecture.
final recentlyWatchedProvider = StreamProvider<List<Media>>((ref) {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final completed = ref.watch(completedIdsProvider).maybeWhen(
        data: (ids) => ids,
        orElse: () => const <int>{},
      );
  return ref
      .watch(watchHistoryRepositoryProvider)
      .watchRecent(limit: 1000)
      .asyncMap((history) async {
    final seen = <int>{};
    final ids = <int>[];
    for (final h in history) {
      if (completed.contains(h.mediaId)) continue; // exclut les termines
      if (seen.add(h.mediaId)) ids.add(h.mediaId);
    }
    final result = <Media>[];
    for (final id in ids) {
      final m = await mediaRepo.getMedia(id);
      if (m != null) result.add(m);
    }
    return result;
  });
});

/// « Ça pourrait vous plaire » : animes qui cumulent les 3 genres FAVORIS
/// (animes terminés/en cours) — INTERSECTION (ET logique).
///
/// Le serveur anime-sama ne filtre que sur un genre à la fois : on scrape donc
/// chaque genre favori séparément, et on garde les slugs présents dans TOUTES
/// les listes. On s'appuie sur la PRÉSENCE dans la liste serveur (fiable), pas
/// sur les tags de genre de la carte : ceux-ci sont tronqués (~5 visibles) et
/// rateraient des animes pourtant classés dans le genre par anime-sama.
/// Vide si aucun genre favori. Exclusion biblio appliquée par la rangée.
final recommendedProvider = FutureProvider<List<Media>>((ref) async {
  final genres = await ref.watch(watchedGenresProvider.future);
  if (genres.isEmpty) return const [];
  final top = genres.take(3).toList();
  final results = await Future.wait(
    top.map((g) => ref.watch(animeSamaByGenreProvider(g).future)),
  );
  if (results.any((l) => l.isEmpty)) {
    // Un genre sans résultat -> intersection forcément vide.
    return const [];
  }

  String slugOf(AnimeSamaCatalogueItem it) =>
      it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);

  // Slugs présents dans CHAQUE liste (= animes ayant TOUS les genres favoris).
  Set<String> common = results.first
      .map(slugOf)
      .where((s) => s.isNotEmpty)
      .toSet();
  final bySlug = <String, AnimeSamaCatalogueItem>{};
  for (final it in results.first) {
    final s = slugOf(it);
    if (s.isNotEmpty) bySlug[s] = it;
  }
  for (final list in results.skip(1)) {
    final slugs = list.map(slugOf).where((s) => s.isNotEmpty).toSet();
    common = common.intersection(slugs);
  }

  final kept = [for (final s in common) if (bySlug[s] != null) bySlug[s]!];
  return itemsToMedia(ref, kept);
});
