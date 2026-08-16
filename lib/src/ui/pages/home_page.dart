/// Page d'accueil façon Netflix : plusieurs rangées horizontales thématiques.
///
/// Ordre des rangées :
///  1. Regardé récemment (historique de lancements récent)
///  2. Continuer à regarder (statut en cours)
///  3. Sortis du moment (planning anime-sama de la semaine)
///  4. Les classiques (liste anime-sama)
///  5. Ça pourrait vous plaire (union des 3 genres favoris : animes finis/en cours)
///  6. Par genre (une rangée par genre favori, du plus au moins présent)
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/logic/effective_status_service.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart';
import '../../services/stream_resolver.dart'
    show AnimeSamaCatalogueItem;
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
    for (final c in current.take(20)) {
      final m = await mediaRepo.getMedia(c.mediaId);
      if (m != null) result.add(m);
    }
    return result;
  });
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
      .watchRecent(limit: 50)
      .asyncMap((history) async {
    final seen = <int>{};
    final ids = <int>[];
    for (final h in history) {
      if (completed.contains(h.mediaId)) continue; // exclut les termines
      if (seen.add(h.mediaId)) ids.add(h.mediaId);
    }
    final result = <Media>[];
    for (final id in ids.take(20)) {
      final m = await mediaRepo.getMedia(id);
      if (m != null) result.add(m);
    }
    return result;
  });
});

/// « Ça pourrait vous plaire » : union des animes (catalogue anime-sama) des 3
/// genres FAVORIS (animes terminés/en cours), dédupliqués. Vide si aucun genre
/// favori connu. Exclusion biblio appliquée par la rangée.
final _recommendedProvider = FutureProvider<List<Media>>((ref) async {
  final genres = await ref.watch(_watchedGenresProvider.future);
  if (genres.isEmpty) return const [];
  final top = genres.take(3);
  final results = await Future.wait(
    top.map((g) => ref.watch(animeSamaByGenreProvider(g).future)),
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
    // Tous les genres favoris (animes finis/en cours), du plus au moins présent.
    final genresAsync = ref.watch(_watchedGenresProvider);

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
        // 2. Continuer à regarder (statut en cours) — bouton reprise. Pas
        //    d'exclusion biblio : ce sont ses propres animes.
        _MediaRow(
          title: 'Continuer à regarder',
          provider: _continueWatchingProvider,
          withResume: true,
        ),
        // 3. Sortis du moment (planning de la semaine).
        _MediaRow(
          title: 'Sortis du moment',
          provider: _recentlyReleasedProvider,
          excludeLibrary: true,
        ),
        // 4. Les classiques (liste anime-sama).
        _MediaRow(
          title: 'Les classiques',
          provider: _classicsProvider,
          excludeLibrary: true,
        ),
        // 5. Ça pourrait vous plaire (union des 3 genres favoris : animes
        //    terminés/en cours).
        _MediaRow(
          title: 'Ca pourrait vous plaire',
          provider: _recommendedProvider,
          excludeLibrary: true,
        ),
        // 6. Par genre : une rangée par genre regardé, par nb de visualisations
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
              if (lib.ids.contains(m.anilistId)) return false;
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
/// boutons flèches gauche/droite (overlay), masqués aux extrémités. La molette
/// verticale défile aussi horizontalement (confort desktop). Liste finie.
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
  final _controller = ScrollController();

  /// Espacement entre cartes (doit correspondre au separatorBuilder).
  static const double _gap = 12;

  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
    // Première évaluation après le premier layout (extents connus).
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void didUpdateWidget(_HorizontalCardList old) {
    super.didUpdateWidget(old);
    // La liste a pu changer (stream) -> réévaluer les flèches.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateArrows);
    _controller.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final canLeft = pos.pixels > 0.5;
    final canRight = pos.pixels < pos.maxScrollExtent - 0.5;
    if (canLeft != _canLeft || canRight != _canRight) {
      setState(() {
        _canLeft = canLeft;
        _canRight = canRight;
      });
    }
  }

  /// Défile d'une « page » (la largeur visible), animé. [dir] = -1 gauche, +1 droite.
  void _scrollBy(int dir) {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final page = pos.viewportDimension - widget.cardWidth * 0.5;
    final target = (pos.pixels + dir * page)
        .clamp(0.0, pos.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Molette verticale -> défilement horizontal (confort desktop).
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      if (!_controller.hasClients) return;
      final target = (_controller.offset + event.scrollDelta.dy)
          .clamp(0.0, _controller.position.maxScrollExtent);
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Listener(
            onPointerSignal: _onPointerSignal,
            child: ScrollConfiguration(
              // Glisser souris/trackpad autorisé ; pas de barre (on a les flèches).
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
                scrollbars: false,
              ),
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (context, i) {
                  final media = widget.items[i];
                  return SizedBox(
                    width: widget.cardWidth,
                    child: MediaCard(
                      media: media,
                      onResume: widget.withResume
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
          ),
          // Flèche gauche (visible seulement si on peut aller à gauche).
          if (_canLeft)
            _CarouselArrow(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left,
              onPressed: () => _scrollBy(-1),
            ),
          // Flèche droite.
          if (_canRight)
            _CarouselArrow(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right,
              onPressed: () => _scrollBy(1),
            ),
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
