library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/media.dart';
import '../pages/home_providers.dart';
import 'app_shell_tv.dart';
import 'widgets/tv_content_row.dart';
import 'widgets/tv_hero_banner.dart';

class HomepageTv extends ConsumerStatefulWidget {
  const HomepageTv({super.key});

  @override
  ConsumerState<HomepageTv> createState() => _HomepageTvState();
}

class _HomepageTvState extends ConsumerState<HomepageTv> {
  Media? _focusedMedia;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onRowFocus(Media media) {
    if (mounted) setState(() => _focusedMedia = media);
  }

  void _onHeroFocus() {
    if (mounted) setState(() => _focusedMedia = null);
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
    final genres = ref.watch(watchedGenresProvider).maybeWhen(
          data: (g) => g.take(3).toList(),
          orElse: () => <String>[],
        );

    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowUp &&
            _scrollController.hasClients &&
            _scrollController.offset <= 0) {
          // Remonte le focus à la navbar TV
          TvFocusScopeProvider.maybeOf(context)?.focusNavBar();
          _onHeroFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        color: Colors.black,
        child: ListView(
          controller: _scrollController,
          children: [
            Focus(
              onFocusChange: (focused) {
                if (focused) _onHeroFocus();
              },
              child: TvHeroBanner(
                items: heroItems,
                focusedMedia: _focusedMedia,
              ),
            ),
            const SizedBox(height: 24),
            if (continueItems.isNotEmpty)
              TvContentRow(
                title: 'Continuer à regarder',
                items: continueItems,
                withResume: true,
                onFocused: _onRowFocus,
                autofocusFirst: true,
              ),
            if (recentItems.isNotEmpty)
              TvContentRow(
                title: 'Regardé récemment',
                items: recentItems,
                withResume: true,
                onFocused: _onRowFocus,
                autofocusFirst: continueItems.isEmpty,
              ),
            if (heroItems.isNotEmpty)
              TvContentRow(
                title: 'Nouvelles sorties',
                items: heroItems,
                onFocused: _onRowFocus,
                autofocusFirst: continueItems.isEmpty && recentItems.isEmpty,
              ),
            if (classicItems.isNotEmpty)
              TvContentRow(
                title: 'Les classiques',
                items: classicItems,
                onFocused: _onRowFocus,
                autofocusFirst: continueItems.isEmpty &&
                    recentItems.isEmpty &&
                    heroItems.isEmpty,
              ),
            for (final genre in genres)
              _GenreRow(
                genre: genre,
                onFocused: _onRowFocus,
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _GenreRow extends ConsumerWidget {
  final String genre;
  final void Function(Media) onFocused;

  const _GenreRow({required this.genre, required this.onFocused});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(byGenreProvider(genre)).maybeWhen(
          data: (i) => i,
          orElse: () => <Media>[],
        );
    if (items.isEmpty) return const SizedBox.shrink();
    return TvContentRow(
      title: genre,
      items: items,
      onFocused: onFocused,
    );
  }
}
