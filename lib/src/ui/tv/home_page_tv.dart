library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/media.dart';
import '../pages/home_providers.dart';
import 'widgets/tv_content_row.dart';
import 'widgets/tv_hero_banner.dart';
import '../widgets/tv_focusable.dart';

class HomepageTv extends ConsumerStatefulWidget {
  const HomepageTv({super.key});

  @override
  ConsumerState<HomepageTv> createState() => _HomepageTvState();
}

class _HomepageTvState extends ConsumerState<HomepageTv> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroItems = ref.watch(recentlyReleasedProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final continueItems = ref.watch(continueWatchingProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final recentItems = ref.watch(recentlyWatchedProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );
    final classicItems = ref.watch(classicsProvider).maybeWhen(
          data: (items) => items,
          orElse: () => <Media>[],
        );

    // Média prioritaire pour le Hero : le dernier en cours, sinon la première sortie
    final featuredMedia = continueItems.isNotEmpty
        ? continueItems.first
        : (heroItems.isNotEmpty ? heroItems.first : null);

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          if (featuredMedia != null)
            TvHeroBanner(
              media: featuredMedia,
              autofocus: true,
            )
          else
            Container(
              height: 240,
              margin: const EdgeInsets.fromLTRB(48, 24, 48, 16),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Bienvenue sur Terebi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vos animes se chargent. Utilisez la télécommande pour naviguer.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TvFocusable(
                          autofocus: true,
                          onPressed: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Chargement des animes…',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (continueItems.isNotEmpty)
            TvContentRow(
              title: 'Continuer à regarder',
              items: continueItems,
              withResume: true,
            ),
          if (recentItems.isNotEmpty)
            TvContentRow(
              title: 'Regardé récemment',
              items: recentItems,
              withResume: true,
            ),
          if (heroItems.isNotEmpty)
            TvContentRow(
              title: 'Nouvelles sorties',
              items: heroItems,
            ),
          if (classicItems.isNotEmpty)
            TvContentRow(
              title: 'Les classiques',
              items: classicItems,
            ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}
