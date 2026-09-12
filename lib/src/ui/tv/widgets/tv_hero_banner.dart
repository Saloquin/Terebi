library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../widgets/anime_sama_image.dart';
import '../media_detail_page_tv.dart';
import 'tv_slide_indicators.dart';

/// Hero plein écran style Netflix pour Android TV.
/// Affiche les [items] en rotation automatique toutes les [rotationSeconds] secondes.
/// [focusedMedia] surcharge l'image de fond quand une tuile de rangée est focusée.
class TvHeroBanner extends ConsumerStatefulWidget {
  final List<Media> items;
  final int rotationSeconds;
  final Media? focusedMedia;

  const TvHeroBanner({
    super.key,
    required this.items,
    this.rotationSeconds = 10,
    this.focusedMedia,
  });

  @override
  ConsumerState<TvHeroBanner> createState() => _TvHeroBannerState();
}

class _TvHeroBannerState extends ConsumerState<TvHeroBanner> {
  int _current = 0;
  Timer? _timer;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: widget.rotationSeconds),
      (_) {
        if (!_hasFocus && mounted && widget.items.isNotEmpty) {
          setState(() => _current = (_current + 1) % widget.items.length);
        }
      },
    );
  }

  Media? get _displayed {
    if (widget.focusedMedia != null) return widget.focusedMedia;
    if (widget.items.isEmpty) return null;
    return widget.items[_current % widget.items.length];
  }

  void _openDetail(BuildContext context) {
    final media = _displayed;
    if (media == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaDetailPageTv(
        mediaId: media.mediaId,
        displayTitle: media.title.preferred,
        animeSamaSlug: media.animeSamaSlug,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = _displayed;
    if (media == null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 64,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final heroHeight = screenHeight - 64;

    return Focus(
      // Le hero est lui-même le focusable : pas de boutons. Flèche gauche/droite
      // change de slide, OK/Centre ouvre les détails du slide courant. Haut/bas
      // ne sont pas interceptés → gérés par le parent (navbar / rangées).
      autofocus: true,
      onFocusChange: (v) => setState(() => _hasFocus = v),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft && widget.items.length > 1) {
          setState(() => _current =
              (_current - 1 + widget.items.length) % widget.items.length);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.items.length > 1) {
          setState(() => _current = (_current + 1) % widget.items.length);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter) {
          _openDetail(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: screenWidth,
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fond : bannière (image large paysage) de l'anime, transition
            // animée. La bannière remplit toute la largeur du hero, contrairement
            // à la cover portrait.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: KeyedSubtree(
                key: ValueKey(media.mediaId),
                child: SizedBox.expand(
                  child: AnimeSamaImage(
                    slug: media.animeSamaSlug ?? '',
                    banner: true,
                    fallbackUrl: media.bannerUrl ?? media.coverUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Gradient haut→bas (noir en bas)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black,
                  ],
                ),
              ),
            ),

            // Gradient gauche (noir à gauche pour lisibilité du texte)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [0.4, 1.0],
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),

            // Texte + boutons
            Positioned(
              left: 64,
              bottom: 80,
              right: screenWidth * 0.45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    media.title.preferred,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (media.genres.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      media.genres.take(3).join(' • '),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),

            // Indicateurs de slide — limités pour ne jamais déborder la largeur
            // (un point par item déborde dès qu'il y a beaucoup de sorties).
            if (widget.items.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: TvSlideIndicators(
                  count: widget.items.length,
                  current: _current,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
