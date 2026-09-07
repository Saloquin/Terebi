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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/anime_id.dart';
import '../../domain/models/media.dart';
import '../widgets/anime_sama_image.dart';
import '../widgets/media_card.dart';
import 'home_providers.dart';
import 'media_detail_page.dart';
import 'resume_helper.dart';

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tous les genres favoris (animes finis/en cours), du plus au moins présent.
    final genresAsync = ref.watch(watchedGenresProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 0. HERO « Nouvelles sorties » : carrousel plein-largeur (banniere +
        //    titre + genres + description), defilement auto toutes les 10 s.
        _HeroCarousel(
          title: 'Nouvelles sorties',
          provider: recentlyReleasedProvider,
        ),
        const SizedBox(height: 24),
        // 1. Regardé récemment (historique récent) — bouton reprise. Pas
        //    d'exclusion biblio : c'est l'historique personnel.
        _MediaRow(
          title: 'Regarde recemment',
          provider: recentlyWatchedProvider,
          withResume: true,
        ),
        // 2. Continuer à regarder (statut en cours) — bouton reprise. Pas
        //    d'exclusion biblio : ce sont ses propres animes.
        _MediaRow(
          title: 'Continuer à regarder',
          provider: continueWatchingProvider,
          withResume: true,
        ),
        // 3. Les classiques (liste anime-sama).
        _MediaRow(
          title: 'Les classiques',
          provider: classicsProvider,
          excludeLibrary: true,
        ),
        // 4. Ça pourrait vous plaire (intersection des 3 genres favoris).
        _MediaRow(
          title: 'Ca pourrait vous plaire',
          provider: recommendedProvider,
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
  List<Media> _items = [];

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

  void _openCurrentSlide(BuildContext context) {
    if (_items.isEmpty) return;
    final media = _items[_index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          mediaId: media.mediaId,
          displayTitle: media.animeSamaTitle,
        ),
      ),
    );
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
        _items = items;
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
                // D-pad sur Android TV : flèches gauche/droite changent le slide,
                // OK/Enter ouvre la fiche du slide courant.
                child: Focus(
                  canRequestFocus: ref.watch(isTvProvider),
                  onKeyEvent: ref.watch(isTvProvider)
                      ? (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowLeft) {
                            _goTo(_index - 1);
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowRight) {
                            _goTo(_index + 1);
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            _openCurrentSlide(context);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        }
                      : null,
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
              ],  // fin enfants Stack
            ), // Stack
          ), // Focus (D-pad TV)
          ),  // ClipRRect
        ),    // SizedBox
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
          final lib = ref.watch(libraryFilterProvider).maybeWhen(
                data: (f) => f,
                orElse: () => (ids: <int>{}, titles: <String>{}),
              );
          if (lib.ids.isNotEmpty || lib.titles.isNotEmpty) {
            items = items.where((m) {
              if (lib.ids.contains(m.mediaId)) return false;
              if (lib.titles.contains(normalizeAnimeTitle(m.title.preferred))) {
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

  /// Un FocusNode par carte — permet la navigation D-pad entre les cartes.
  late final List<FocusNode> _focusNodes;

  /// Pas d'une carte (largeur + espacement) — sert au défilement par flèche.
  double get _step => widget.cardWidth + _gap;

  /// Vrai si la liste est « bouclable » (au moins 2 cartes) : sinon rien à faire
  /// défiler, pas de flèches.
  bool get _loopable => widget.items.length > 1;

  @override
  void initState() {
    super.initState();
    // Un nœud de focus par élément : navigation D-pad horizontale.
    _focusNodes = List.generate(widget.items.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    // Libère les nœuds avant le ScrollController.
    for (final fn in _focusNodes) {
      fn.dispose();
    }
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
          // FocusTraversalGroup isole la traversée D-pad dans cette rangée.
          FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: ListView.builder(
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
                    focusNode: _focusNodes[i],
                    onFocused: () {
                      // Scroll direct via le controller (NeverScrollableScrollPhysics
                      // bloque Scrollable.ensureVisible — animateTo fonctionne toujours).
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_controller.hasClients) return;
                        final pos = _controller.position;
                        final target = (i * _step -
                                (pos.viewportDimension - widget.cardWidth) / 2)
                            .clamp(0.0, pos.maxScrollExtent);
                        _controller.animateTo(
                          target,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      });
                    },
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
      provider: byGenreProvider(genre),
      excludeLibrary: true,
    );
  }
}
