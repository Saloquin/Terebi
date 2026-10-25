library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/media.dart';
import '../pages/home_providers.dart';
import 'widgets/tv_content_row.dart';
import 'widgets/tv_hero_banner.dart';

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
            const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
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
