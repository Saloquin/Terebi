/// Page d'accueil mobile optimisée pour écran tactile vertical.
/// Inclut : Hero carrousel compact, carte de reprise rapide 1-clic,
/// et rangées de médias horizontales à défilement fluide.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/media.dart';
import '../pages/home_providers.dart';
import '../pages/media_detail_page.dart';
import '../pages/resume_helper.dart';
import '../widgets/anime_sama_image.dart';

class HomePageMobile extends ConsumerWidget {
  const HomePageMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatchingAsync = ref.watch(continueWatchingProvider);
    final genresAsync = ref.watch(watchedGenresProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recentlyReleasedProvider);
        ref.invalidate(continueWatchingProvider);
        ref.invalidate(classicsProvider);
        ref.invalidate(recommendedProvider);
        ref.invalidate(watchedGenresProvider);
        try {
          await ref.read(syncServiceProvider).fullSync();
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 0. Hero carrousel mobile (visuel haut de page plein format)
          _HeroCarouselMobile(
            provider: recentlyReleasedProvider,
          ),
          const SizedBox(height: 20),

          // 1. Carte Reprise Rapide (si un anime est en cours)
          continueWatchingAsync.maybeWhen(
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              final latest = items.first;
              return Column(
                children: [
                  _QuickResumeCard(media: latest),
                  const SizedBox(height: 20),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // 2. Continuer à regarder (si au moins 2 animes en cours)
          continueWatchingAsync.maybeWhen(
            data: (items) {
              if (items.length <= 1) return const SizedBox.shrink();
              return Column(
                children: [
                  _MobileMediaRow(
                    title: 'Continuer à regarder',
                    items: items.sublist(1),
                    withResume: true,
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // 3. Nouvelles sorties
          _MobileMediaRowFromProvider(
            title: 'Nouvelles sorties',
            provider: recentlyReleasedProvider,
          ),
          const SizedBox(height: 20),

          // 4. Les classiques
          _MobileMediaRowFromProvider(
            title: 'Les classiques incontournables',
            provider: classicsProvider,
            excludeLibrary: true,
          ),
          const SizedBox(height: 20),

          // 5. Recommandations
          _MobileMediaRowFromProvider(
            title: 'Ça pourrait vous plaire',
            provider: recommendedProvider,
            excludeLibrary: true,
          ),
          const SizedBox(height: 20),

          // 6. Rangées par genres favoris
          ...genresAsync.maybeWhen(
            data: (genres) => genres.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _MobileGenreRow(genre: g),
                )),
            orElse: () => const <Widget>[],
          ),
        ],
      ),
    );
  }
}

/// Carrousel Hero adapté au format smartphone
class _HeroCarouselMobile extends ConsumerStatefulWidget {
  final ProviderListenable<AsyncValue<List<Media>>> provider;
  const _HeroCarouselMobile({required this.provider});

  @override
  ConsumerState<_HeroCarouselMobile> createState() => _HeroCarouselMobileState();
}

class _HeroCarouselMobileState extends ConsumerState<_HeroCarouselMobile> {
  final _pageController = PageController();
  Timer? _timer;
  int _currentIndex = 0;
  List<Media> _items = [];

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_items.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_pageController.hasClients || _items.isEmpty) return;
      final next = (_currentIndex + 1) % _items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(widget.provider);
    final theme = Theme.of(context);

    return mediaAsync.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        _items = items.take(6).toList();
        if (_timer == null) _restartTimer();

        return Column(
          children: [
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (i) {
                    setState(() => _currentIndex = i);
                    _restartTimer();
                  },
                  itemBuilder: (context, i) {
                    final media = _items[i];
                    final title = media.title.preferred;
                    final banner = media.bannerUrl ?? media.coverUrl;
                    final slug = media.animeSamaSlug ?? '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MediaDetailPage(
                              mediaId: media.mediaId,
                              displayTitle: media.animeSamaTitle,
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (slug.isNotEmpty)
                            AnimeSamaImage(
                              slug: slug,
                              fallbackUrl: banner,
                              fit: BoxFit.cover,
                            )
                          else if (banner != null)
                            Image.network(banner, fit: BoxFit.cover)
                          else
                            Container(color: theme.colorScheme.surfaceContainerHighest),

                          // Dégradé sombre pour lisibilité
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                stops: const [0.3, 0.6, 1.0],
                              ),
                            ),
                          ),

                          // Badge « Nouveauté »
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'À LA UNE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          // Infos et bouton
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 4,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (media.genres.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          media.genres.take(3).join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                  label: const Text('Voir'),
                                  onPressed: () => resumePlayback(context, ref, media),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Indicateurs de page (points)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Carte de reprise rapide (action 1-tap pour continuer le visionnage)
class _QuickResumeCard extends ConsumerWidget {
  final Media media;
  const _QuickResumeCard({required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slug = media.animeSamaSlug ?? '';
    final cover = media.coverUrl;
    final title = media.title.preferred;

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => resumePlayback(context, ref, media),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster vignette
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 65,
                  height: 90,
                  child: slug.isNotEmpty
                      ? AnimeSamaImage(
                          slug: slug,
                          fallbackUrl: cover,
                          fit: BoxFit.cover,
                        )
                      : (cover != null
                          ? Image.network(cover, fit: BoxFit.cover)
                          : Container(color: colorScheme.surfaceContainerHighest)),
                ),
              ),
              const SizedBox(width: 14),

              // Détails et bouton de reprise
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_rounded,
                            size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'CONTINUER LA LECTURE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.play_circle_fill, size: 18),
                      label: const Text('Reprendre'),
                      onPressed: () => resumePlayback(context, ref, media),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée de médias pour smartphone depuis une liste déjà résolue
class _MobileMediaRow extends StatelessWidget {
  final String title;
  final List<Media> items;
  final bool withResume;

  const _MobileMediaRow({
    required this.title,
    required this.items,
    this.withResume = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _MobileMediaCard(
              media: items[i],
              withResume: withResume,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rangée de médias alimentée par un provider
class _MobileMediaRowFromProvider extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Media>>> provider;
  final bool excludeLibrary;

  const _MobileMediaRowFromProvider({
    required this.title,
    required this.provider,
    this.excludeLibrary = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(provider);
    final completed = ref.watch(completedIdsProvider).maybeWhen(
          data: (ids) => ids,
          orElse: () => const <int>{},
        );

    return mediaAsync.maybeWhen(
      data: (items) {
        var filtered = items;
        if (excludeLibrary) {
          filtered = items.where((m) => !completed.contains(m.mediaId)).toList();
        }
        if (filtered.isEmpty) return const SizedBox.shrink();

        return _MobileMediaRow(
          title: title,
          items: filtered,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Rangée par genre
class _MobileGenreRow extends StatelessWidget {
  final String genre;
  const _MobileGenreRow({required this.genre});

  @override
  Widget build(BuildContext context) {
    return _MobileMediaRowFromProvider(
      title: 'Recommandé - $genre',
      provider: byGenreProvider(genre),
      excludeLibrary: true,
    );
  }
}

/// Carte média individuelle tactile pour mobile
class _MobileMediaCard extends StatelessWidget {
  final Media media;
  final bool withResume;

  const _MobileMediaCard({
    required this.media,
    this.withResume = false,
  });

  @override
  Widget build(BuildContext context) {
    final slug = media.animeSamaSlug ?? '';
    final cover = media.coverUrl;
    final title = media.title.preferred;
    final theme = Theme.of(context);

    return SizedBox(
      width: 120,
      child: Consumer(
        builder: (context, ref, _) => GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaDetailPage(
                  mediaId: media.mediaId,
                  displayTitle: media.animeSamaTitle,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Couverture avec coins arrondis et ombre subtile
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: slug.isNotEmpty
                          ? AnimeSamaImage(
                              slug: slug,
                              fallbackUrl: cover,
                              fit: BoxFit.cover,
                            )
                          : (cover != null
                              ? Image.network(cover, fit: BoxFit.cover)
                              : Container(color: theme.colorScheme.surfaceContainerHighest)),
                    ),
                    // Bouton play discret en bas à droite
                    if (withResume)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            onTap: () => resumePlayback(context, ref, media),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Titre sur 2 lignes maximum
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
