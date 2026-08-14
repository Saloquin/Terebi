/// Page d'accueil façon Netflix : plusieurs rangées horizontales thématiques.
///
/// Ordre des rangées :
///  1. Regardé récemment (historique de lancements récent)
///  2. En ce moment (historique de lancements agrégé par fréquence)
///  3. Continuer à regarder (statut en cours)
///  4. Sortis du moment (planning anime-sama de la semaine)
///  5. Les classiques (liste anime-sama)
///  6. Derniers contenus ajoutes (catalogue anime-sama)
///  7. Ca pourrait vous plaire (union des genres favoris)
///  8. Par genre (catalogue anime-sama, une rangée par genre, ordre alphabétique)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart'
    show AnimeSamaCatalogueItem;
import '../widgets/media_card.dart';
import 'library_page.dart' show entriesByStatusProvider;
import 'media_detail_page.dart';
import 'resume_helper.dart';

// ---------------------------------------------------------------------------
// Providers de rangées
// ---------------------------------------------------------------------------

/// « Continuer à regarder » : médias en cours, triés du plus récemment mis à
/// jour au plus ancien, résolus en [Media] (cache local).
final _continueWatchingProvider = FutureProvider<List<Media>>((ref) async {
  final entries =
      await ref.watch(entriesByStatusProvider(ListStatus.current).future);
  final sorted = [...entries]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  for (final e in sorted.take(20)) {
    final m = await mediaRepo.getMedia(e.mediaId);
    if (m != null) result.add(m);
  }
  return result;
});

/// « Sortis du moment » : planning anime-sama de la semaine, résolu en Media via
/// le slug (cache DB si dispo, sinon carte minimale). Best-effort, borné.
final _recentlyReleasedProvider = FutureProvider<List<Media>>((ref) async {
  try {
    final items = await ref.watch(animeSamaPlanningProvider.future);
    final result = <Media>[];
    final seen = <int>{};
    for (final it in items.take(15)) {
      final slug = it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);
      if (slug.isEmpty) continue;
      final id = animeSamaIdForSlug(slug);
      if (!seen.add(id)) continue;
      final cached = await ref.watch(mediaRepositoryProvider).getMedia(id);
      result.add(cached ?? Media.fromAnimeSama(slug: slug, title: it.title));
      if (result.length >= 12) break;
    }
    return result;
  } catch (_) {
    return const [];
  }
});

/// Convertit une liste d'items catalogue anime-sama en Media (cache-first).
Future<List<Media>> _itemsToMedia(
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
  return result;
}

/// « Les classiques » (home anime-sama).
final _classicsProvider = FutureProvider<List<Media>>((ref) async {
  final home = await ref.watch(animeSamaHomeProvider.future);
  return _itemsToMedia(ref, home.classics);
});

/// « Derniers episodes ajoutes » (home anime-sama).
final _latestProvider = FutureProvider<List<Media>>((ref) async {
  final home = await ref.watch(animeSamaHomeProvider.future);
  return _itemsToMedia(ref, home.latestEpisodes);
});

/// Recommandations par genre (catalogue anime-sama).
final _byGenreProvider =
    FutureProvider.family<List<Media>, String>((ref, genre) async {
  final items = await ref.watch(animeSamaByGenreProvider(genre).future);
  return _itemsToMedia(ref, items);
});

/// Genres favoris de l'utilisateur (les plus présents dans sa bibliothèque),
/// classés par occurrence décroissante. Retourne au plus [max] genres.
final _favoriteGenresProvider =
    FutureProvider.family<List<String>, int>((ref, max) async {
  final all = await ref.watch(mediaRepositoryProvider).getAllMedia();
  final entries = await ref.watch(listRepositoryProvider).getAllEntries();
  final followed = entries.map((e) => e.mediaId).toSet();
  final counts = <String, int>{};
  for (final m in all) {
    if (!followed.contains(m.anilistId)) continue;
    for (final g in m.genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return sorted.take(max).toList();
});

/// Ensemble des ids déjà présents dans la bibliothèque (toute entrée de liste).
/// Sert à EXCLURE ces animes des rangées de découverte.
final _libraryFilterProvider =
    FutureProvider<({Set<int> ids, Set<String> titles})>((ref) async {
  final entries = await ref.watch(listRepositoryProvider).getAllEntries();
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final ids = <int>{};
  final titles = <String>{};
  for (final e in entries) {
    ids.add(e.mediaId);
    final m = await mediaRepo.getMedia(e.mediaId);
    if (m != null) {
      titles.add(_normTitle(m.title.preferred));
      if (m.animeSamaTitle != null) titles.add(_normTitle(m.animeSamaTitle!));
    }
  }
  return (ids: ids, titles: titles);
});

/// Normalise un titre pour comparaison (minuscule, alphanumérique).
String _normTitle(String t) =>
    t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// « En ce moment » : ce que l'utilisateur regarde activement, dérivé de son
/// historique de lancements agrégé (le plus lancé d'abord), résolu en [Media].
final _mostWatchedProvider = FutureProvider<List<Media>>((ref) async {
  final history = await ref.watch(watchHistoryRepositoryProvider).all();
  if (history.isEmpty) return const [];
  final counts = <int, int>{};
  for (final h in history) {
    counts[h.mediaId] = (counts[h.mediaId] ?? 0) + 1;
  }
  final ids = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  for (final id in ids.take(20)) {
    final m = await mediaRepo.getMedia(id);
    if (m != null) result.add(m);
  }
  return result;
});

/// « Regarde recemment » : les derniers animes LANCES (historique recent, ordre
/// chronologique inverse), dedupliques par mediaId. Distinct d'« En ce moment »
/// (qui agrege par frequence). Resolu en [Media] via le cache local.
final _recentlyWatchedProvider = FutureProvider<List<Media>>((ref) async {
  final history =
      await ref.watch(watchHistoryRepositoryProvider).recent(limit: 50);
  final seen = <int>{};
  final ids = <int>[];
  for (final h in history) {
    if (seen.add(h.mediaId)) ids.add(h.mediaId);
  }
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final result = <Media>[];
  for (final id in ids.take(20)) {
    final m = await mediaRepo.getMedia(id);
    if (m != null) result.add(m);
  }
  return result;
});

/// « Ça pourrait vous plaire » : union des animes (catalogue anime-sama) des 3
/// genres les plus présents dans la bibliothèque, dédupliqués. Vide si aucun
/// genre favori connu. Exclusion biblio appliquée par la rangée.
final _recommendedProvider = FutureProvider<List<Media>>((ref) async {
  final genres = await ref.watch(_favoriteGenresProvider(3).future);
  if (genres.isEmpty) return const [];
  final results = await Future.wait(
    genres.map((g) => ref.watch(animeSamaByGenreProvider(g).future)),
  );
  final seen = <int>{};
  final all = <AnimeSamaCatalogueItem>[];
  for (final list in results) {
    for (final it in list) {
      final slug = it.slug.isNotEmpty ? it.slug : slugFromCatalogueUrl(it.url);
      if (slug.isEmpty) continue;
      if (seen.add(animeSamaIdForSlug(slug))) all.add(it);
    }
  }
  return _itemsToMedia(ref, all);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jusqu'à 10 genres pour les rangées par genre ; triés alphabétiquement.
    final genresAsync = ref.watch(_favoriteGenresProvider(10));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Regardé récemment (historique récent) — bouton reprise. Pas
        //    d'exclusion biblio : c'est l'historique personnel.
        _MediaRow(
          title: 'Regarde recemment',
          provider: _recentlyWatchedProvider,
          withResume: true,
        ),
        // 2. En ce moment (historique agrégé par fréquence) — bouton reprise.
        _MediaRow(
          title: 'En ce moment',
          provider: _mostWatchedProvider,
          withResume: true,
        ),
        // 3. Continuer à regarder (statut en cours) — bouton reprise.
        _MediaRow(
          title: 'Continuer à regarder',
          provider: _continueWatchingProvider,
          withResume: true,
        ),
        // 4. Sortis du moment (planning de la semaine).
        _MediaRow(
          title: 'Sortis du moment',
          provider: _recentlyReleasedProvider,
          excludeLibrary: true,
        ),
        // 5. Les classiques (liste anime-sama).
        _MediaRow(
          title: 'Les classiques',
          provider: _classicsProvider,
          excludeLibrary: true,
        ),
        // 6. Derniers contenus ajoutés (catalogue anime-sama).
        _MediaRow(
          title: 'Derniers contenus ajoutes',
          provider: _latestProvider,
          excludeLibrary: true,
        ),
        // 7. Ça pourrait vous plaire (union des genres favoris).
        _MediaRow(
          title: 'Ca pourrait vous plaire',
          provider: _recommendedProvider,
          excludeLibrary: true,
        ),
        // 8. Par genre : une rangée par genre, en ordre alphabétique.
        ...genresAsync.maybeWhen(
          data: (genres) {
            final sorted = [...genres]..sort();
            return sorted.map((g) => _GenreRow(genre: g)).toList();
          },
          orElse: () => const <Widget>[],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rangée horizontale réutilisable
// ---------------------------------------------------------------------------

/// Rangée horizontale de [MediaCard], grande taille façon Netflix, à
/// défilement EN BOUCLE (on revient au début après le dernier). Masquée si
/// vide/chargement/erreur.
class _MediaRow extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Media>>> provider;
  final bool withResume;
  final bool excludeLibrary;

  /// Nombre max de cartes par rangée (borne le carrousel).
  static const int _maxCards = 20;

  /// Nombre MIN de cartes pour activer la boucle infinie.
  static const int _minCardsForLoop = 13;

  /// Largeur/hauteur des grandes cartes.
  static const double _cardWidth = 200;
  static const double _rowHeight = 320;

  const _MediaRow({
    required this.title,
    required this.provider,
    this.withResume = false,
    this.excludeLibrary = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.maybeWhen(
      data: (raw) {
        var items = raw;

        // Exclusion des animes déjà en bibliothèque.
        if (excludeLibrary) {
          final lib = ref.watch(_libraryFilterProvider).maybeWhen(
                data: (f) => f,
                orElse: () => (ids: <int>{}, titles: <String>{}),
              );
          if (lib.ids.isNotEmpty || lib.titles.isNotEmpty) {
            items = items.where((m) {
              if (lib.ids.contains(m.anilistId)) return false;
              if (lib.titles.contains(_normTitle(m.title.preferred))) {
                return false;
              }
              return true;
            }).toList();
          }
        }

        // Borne le nombre de cartes.
        if (items.length > _maxCards) items = items.sublist(0, _maxCards);

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: _rowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length < _minCardsForLoop
                    ? items.length
                    : 100000,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final media = items[i % items.length];
                  return SizedBox(
                    width: _cardWidth,
                    child: MediaCard(
                      media: media,
                      onResume: withResume
                          ? () => resumePlayback(context, ref, media)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaDetailPage(
                            anilistId: media.anilistId,
                            displayTitle: media.animeSamaTitle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Rangée « Recommande · `<genre>` » (découverte anime-sama par genre).
class _GenreRow extends StatelessWidget {
  final String genre;
  const _GenreRow({required this.genre});

  @override
  Widget build(BuildContext context) {
    return _MediaRow(
      title: 'Recommande - $genre',
      provider: _byGenreProvider(genre),
      excludeLibrary: true,
    );
  }
}
