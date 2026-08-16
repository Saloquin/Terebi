/// Page d'accueil façon Netflix : un hero en haut puis des rangées horizontales.
///
/// Ordre :
///  0. Hero « Sortis du moment » (carrousel plein-largeur, défilement auto 10 s)
///  1. Regardé récemment (historique de lancements récent)
///  2. Continuer à regarder (statut en cours)
///  3. Les classiques (liste anime-sama)
///  4. Ça pourrait vous plaire (intersection des 3 genres favoris)
///  5. Par genre (une rangée par genre favori, du plus au moins présent)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/logic/effective_status_service.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart'
    show AnimeSamaCatalogueItem;
import '../widgets/anime_sama_image.dart';
import '../widgets/media_card.dart';
import 'media_detail_page.dart';
import 'resume_helper.dart';

// ---------------------------------------------------------------------------
// Providers de rangées
// ---------------------------------------------------------------------------

/// Ids des animes TERMINÉS (statut completed). Sert à les exclure des rangées
/// « Regardé récemment » et « Continuer à regarder » (un anime fini n'est ni à
/// reprendre ni en cours). Réactif via le stream du repository de listes.
final _completedIdsProvider = StreamProvider<Set<int>>((ref) {
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
final _continueWatchingProvider = StreamProvider<List<Media>>((ref) {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final seasonProgress = ref.watch(seasonProgressRepositoryProvider);
  return ref
      .watch(listRepositoryProvider)
      .watchAllEntries()
      .asyncMap((all) async {
    final current = <({DateTime updatedAt, int mediaId})>[];
    for (final e in all) {
      final hasProgress =
          e.progress > 0 || await seasonProgress.hasAnyProgress(e.mediaId);
      final eff = effectiveStatus(entry: e, hasProgress: hasProgress);
      if (eff == ListStatus.current) {
        current.add((updatedAt: e.updatedAt, mediaId: e.mediaId));
      }
    }
    current.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final result = <Media>[];
    for (final c in current) {
      final m = await mediaRepo.getMedia(c.mediaId);
      if (m != null) result.add(m);
    }
    return result;
  });
});

/// « Sortis du moment » : planning anime-sama de la semaine, résolu en Media via
/// le slug (cache DB si dispo, sinon carte minimale). Best-effort.
final _recentlyReleasedProvider = FutureProvider<List<Media>>((ref) async {
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
/// Convertit une liste d'items catalogue anime-sama en Media (cache-first).
///
/// L'ordre est MÉLANGÉ (aléatoire) : les rangées de découverte (classiques, par
/// genre, « Ça pourrait vous plaire ») évitent ainsi d'afficher toujours les
/// mêmes animes en tête (le catalogue anime-sama est trié alphabétiquement).
/// Re-mélangé à chaque calcul du provider. N'affecte PAS les rangées « Continuer
/// à regarder » / « Regardé récemment » / « Sortis du moment » (elles n'utilisent
/// pas cette fonction et gardent leur ordre chronologique).
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
  result.shuffle();
  return result;
}

/// « Les classiques » (home anime-sama).
final _classicsProvider = FutureProvider<List<Media>>((ref) async {
  final home = await ref.watch(animeSamaHomeProvider.future);
  return _itemsToMedia(ref, home.classics);
});

/// Recommandations par genre (catalogue anime-sama).
final _byGenreProvider =
    FutureProvider.family<List<Media>, String>((ref, genre) async {
  final items = await ref.watch(animeSamaByGenreProvider(genre).future);
  return _itemsToMedia(ref, items);
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
final _watchedGenresProvider = FutureProvider<List<String>>((ref) async {
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

/// « Regarde recemment » : les derniers animes LANCES (historique recent, ordre
/// chronologique inverse), dedupliques par mediaId, en EXCLUANT les animes
/// termines. Reactif (stream) : se met a jour a chaque lancement de lecture.
final _recentlyWatchedProvider = StreamProvider<List<Media>>((ref) {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final completed = ref.watch(_completedIdsProvider).maybeWhen(
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
final _recommendedProvider = FutureProvider<List<Media>>((ref) async {
  final genres = await ref.watch(_watchedGenresProvider.future);
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
  return _itemsToMedia(ref, kept);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tous les genres favoris (animes finis/en cours), du plus au moins présent.
    final genresAsync = ref.watch(_watchedGenresProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 0. HERO « Nouvelles sorties » : carrousel plein-largeur (banniere +
        //    titre + genres + description), defilement auto toutes les 10 s.
        _HeroCarousel(
          title: 'Nouvelles sorties',
          provider: _recentlyReleasedProvider,
        ),
        const SizedBox(height: 24),
        // 1. Regardé récemment (historique récent) — bouton reprise. Pas
        //    d'exclusion biblio : c'est l'historique personnel.
        _MediaRow(
          title: 'Regarde recemment',
          provider: _recentlyWatchedProvider,
          withResume: true,
        ),
        // 2. Continuer à regarder (statut en cours) — bouton reprise. Pas
        //    d'exclusion biblio : ce sont ses propres animes.
        _MediaRow(
          title: 'Continuer à regarder',
          provider: _continueWatchingProvider,
          withResume: true,
        ),
        // 3. Les classiques (liste anime-sama).
        _MediaRow(
          title: 'Les classiques',
          provider: _classicsProvider,
          excludeLibrary: true,
        ),
        // 4. Ça pourrait vous plaire (intersection des 3 genres favoris).
        _MediaRow(
          title: 'Ca pourrait vous plaire',
          provider: _recommendedProvider,
          excludeLibrary: true,
        ),
        // 5. Par genre : une rangée par genre regardé, par nb de visualisations
        //    décroissant (l'ordre du provider est déjà celui-là).
        ...genresAsync.maybeWhen(
          data: (genres) => genres.map((g) => _GenreRow(genre: g)).toList(),
          orElse: () => const <Widget>[],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero carrousel (plein-largeur, une image à la fois)
// ---------------------------------------------------------------------------

/// Carrousel « hero » plein-largeur : une bannière à la fois, titre + genres +
/// description tronquée en surimpression. Défile automatiquement toutes les 10 s
/// (mis en pause ~10 s après une action manuelle). Flèches + points cliquables.
/// Clic sur la bannière -> fiche. Masqué tant qu'aucun média.
class _HeroCarousel extends ConsumerStatefulWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Media>>> provider;
  const _HeroCarousel({required this.title, required this.provider});

  @override
  ConsumerState<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<_HeroCarousel> {
  static const double _height = 340;

  final _pageController = PageController();
  Timer? _timer;
  int _index = 0;
  int _count = 0;

  /// Durée entre deux slides (secondes), réglable dans les Paramètres.
  int _rotationSeconds = 10;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_count <= 1) return;
    _timer = Timer.periodic(
      Duration(seconds: _rotationSeconds),
      (_) => _goTo(_index + 1, auto: true),
    );
  }

  void _goTo(int i, {bool auto = false}) {
    if (_count == 0 || !_pageController.hasClients) return;
    final next = ((i % _count) + _count) % _count; // wrap circulaire
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
    if (!auto) _restartTimer(); // action manuelle -> repart pour 10 s
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(widget.provider);
    // Durée de rotation réglable : redémarre le timer si elle change.
    final rotation = ref.watch(heroRotationSecondsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => _rotationSeconds,
        );
    return async.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        // (Re)démarre le timer si le nombre d'items OU la durée a changé.
        if (items.length != _count || rotation != _rotationSeconds) {
          _count = items.length;
          _rotationSeconds = rotation;
          WidgetsBinding.instance.addPostFrameCallback((_) => _restartTimer());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: _height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _HeroSlide(media: items[i]),
                ),
                // Flèche gauche.
                if (items.length > 1)
                  _CarouselArrow(
                    alignment: Alignment.centerLeft,
                    icon: Icons.chevron_left,
                    onPressed: () => _goTo(_index - 1),
                  ),
                // Flèche droite.
                if (items.length > 1)
                  _CarouselArrow(
                    alignment: Alignment.centerRight,
                    icon: Icons.chevron_right,
                    onPressed: () => _goTo(_index + 1),
                  ),
                // Points indicateurs.
                if (items.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          GestureDetector(
                            onTap: () => _goTo(i),
                            child: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _index
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Une slide du hero : bannière plein cadre + dégradé + titre/genres/description.
/// Enrichit le média (bannière/description/genres) via le cache anime-sama quand
/// le média du planning est minimal. Clic -> fiche.
class _HeroSlide extends ConsumerWidget {
  final Media media;
  const _HeroSlide({required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = media.animeSamaSlug;
    // Média enrichi (cache-first) si un slug est connu, sinon le média tel quel.
    final enriched = (slug != null && slug.isNotEmpty)
        ? ref.watch(animeSamaDetailProvider(slug)).maybeWhen(
              data: (m) => m ?? media,
              orElse: () => media,
            )
        : media;

    final title = enriched.animeSamaTitle ?? enriched.title.preferred;
    final genres = enriched.genres.take(4).toList();
    final desc = enriched.description;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaDetailPage(
            mediaId: enriched.mediaId,
            displayTitle: enriched.animeSamaTitle,
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Bannière dérivée du slug (cascade d'extensions), repli bannerUrl.
          if (slug != null && slug.isNotEmpty)
            AnimeSamaImage(
              slug: slug,
              banner: true,
              fallbackUrl: enriched.bannerUrl,
              fit: BoxFit.cover,
            )
          else
            Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          // Dégradé pour lisibilité du texte.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black87, Colors.black26, Colors.transparent],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
          // Texte : titre + genres + description (tronquée).
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final g in genres)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(g,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                    ],
                  ),
                ],
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 640,
                    child: Text(
                      desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rangée horizontale réutilisable
// ---------------------------------------------------------------------------

/// Rangée horizontale de [MediaCard], grande taille façon Netflix. Masquée si
/// vide/chargement/erreur.
class _MediaRow extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Media>>> provider;
  final bool withResume;
  final bool excludeLibrary;

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
              if (lib.ids.contains(m.mediaId)) return false;
              if (lib.titles.contains(_normTitle(m.title.preferred))) {
                return false;
              }
              return true;
            }).toList();
          }
        }

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _HorizontalCardList(
              items: items,
              withResume: withResume,
              cardWidth: _cardWidth,
              height: _rowHeight,
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Carrousel horizontal de grandes cartes façon Netflix : défilement par
/// boutons flèches gauche/droite (overlay), toujours visibles (si >1 carte). La
/// liste est FINIE ; les boutons bouclent aux extrémités : au bout à droite, un
/// clic revient au début ; au début, la flèche gauche va à la fin. La molette
/// verticale défile aussi horizontalement (confort desktop).
class _HorizontalCardList extends ConsumerStatefulWidget {
  final List<Media> items;
  final bool withResume;
  final double cardWidth;
  final double height;

  const _HorizontalCardList({
    required this.items,
    required this.withResume,
    required this.cardWidth,
    required this.height,
  });

  @override
  ConsumerState<_HorizontalCardList> createState() =>
      _HorizontalCardListState();
}

class _HorizontalCardListState extends ConsumerState<_HorizontalCardList> {
  /// Espacement entre cartes (doit correspondre au padding des tuiles).
  static const double _gap = 12;

  final ScrollController _controller = ScrollController();

  /// Pas d'une carte (largeur + espacement) — sert au défilement par flèche.
  double get _step => widget.cardWidth + _gap;

  /// Vrai si la liste est « bouclable » (au moins 2 cartes) : sinon rien à faire
  /// défiler, pas de flèches.
  bool get _loopable => widget.items.length > 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Défile d'une « page » (largeur visible), animé. [dir] = -1 gauche, +1 droite.
  /// BOUCLE aux extrémités : au bout à droite, un clic supplémentaire revient au
  /// début ; au début, la flèche gauche va à la fin (façon carrousel).
  void _scrollBy(int dir) {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final max = pos.maxScrollExtent;
    // Nombre entier de cartes tenant dans la fenêtre (au moins 1).
    final perPage = (pos.viewportDimension / _step).floor().clamp(1, 999);
    final page = perPage * _step;

    double target;
    if (dir > 0) {
      // Vers la droite : si on est deja (quasi) au bout, on reboucle au debut.
      target = pos.pixels >= max - 1 ? 0.0 : (pos.pixels + page).clamp(0.0, max);
    } else {
      // Vers la gauche : si on est deja (quasi) au debut, on va a la fin.
      target = pos.pixels <= 1 ? max : (pos.pixels - page).clamp(0.0, max);
    }
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // Aucun scroll souris/molette/glisser : le carrousel se pilote
          // UNIQUEMENT via les boutons flèches (NeverScrollableScrollPhysics).
          ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            // itemExtent FIXE = positionnement O(1) (layout rapide) et pas
            // aligne pour le defilement par fleche. Le gap est un padding.
            itemExtent: _step,
            itemCount: n,
            itemBuilder: (context, i) {
              final media = widget.items[i];
              // Gap gere par un padding a droite (itemExtent inclut _gap).
              return Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: MediaCard(
                  media: media,
                  onResume: widget.withResume
                      ? () => resumePlayback(context, ref, media)
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaDetailPage(
                        mediaId: media.mediaId,
                        displayTitle: media.animeSamaTitle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Flèches toujours présentes tant que la liste est bouclable.
          if (_loopable) ...[
            _CarouselArrow(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left,
              onPressed: () => _scrollBy(-1),
            ),
            _CarouselArrow(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right,
              onPressed: () => _scrollBy(1),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton flèche d'un carrousel, ancré à gauche ou à droite, centré verticalement.
class _CarouselArrow extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onPressed;

  const _CarouselArrow({
    required this.alignment,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            iconSize: 28,
            tooltip: icon == Icons.chevron_left ? 'Précédent' : 'Suivant',
            onPressed: onPressed,
          ),
        ),
      ),
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
