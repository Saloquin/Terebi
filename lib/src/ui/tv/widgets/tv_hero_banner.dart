library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../widgets/anime_sama_image.dart';
import '../../widgets/tv_focusable.dart';
import '../media_detail_page_tv.dart';
import '../../pages/resume_helper.dart';

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

  void _play(BuildContext context) {
    final media = _displayed;
    if (media == null) return;
    resumePlayback(context, ref, media);
  }

  void _openDetail(BuildContext context) {
    final media = _displayed;
    if (media == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaDetailPageTv(
        mediaId: media.mediaId,
        displayTitle: media.title.preferred,
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
      onFocusChange: (v) => setState(() => _hasFocus = v),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.items.length > 1) {
          setState(() =>
              _current = (_current - 1 + widget.items.length) % widget.items.length);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.items.length > 1) {
          setState(() => _current = (_current + 1) % widget.items.length);
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
            // Fond : cover de l'anime avec transition animée
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: KeyedSubtree(
                key: ValueKey(media.mediaId),
                child: AnimeSamaImage(
                  slug: media.animeSamaSlug ?? '',
                  fallbackUrl: media.coverUrl,
                  fit: BoxFit.cover,
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
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TvFocusable(
                        autofocus: true,
                        onPressed: () => _play(context),
                        child: FilledButton.icon(
                          onPressed: () => _play(context),
                          icon: const Icon(Icons.play_arrow, size: 22),
                          label: const Text('Lire',
                              style: TextStyle(fontSize: 16)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TvFocusable(
                        onPressed: () => _openDetail(context),
                        child: OutlinedButton.icon(
                          onPressed: () => _openDetail(context),
                          icon: const Icon(Icons.info_outline,
                              size: 20, color: Colors.white),
                          label: const Text('Détails',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            side:
                                const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Indicateurs de slide
            if (widget.items.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < widget.items.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _current ? 24.0 : 8.0,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == _current
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
