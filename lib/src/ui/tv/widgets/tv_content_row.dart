library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../pages/resume_helper.dart';
import '../../widgets/anime_sama_image.dart';
import '../../widgets/tv_focusable.dart';
import '../media_detail_page_tv.dart';

// Nombre de tuiles visibles simultanément (référence pour le calcul de largeur)
const double _tilesVisible = 5.2;
// Ratio 16:9
const double _tileAspectRatio = 16 / 9;
// Padding horizontal de la rangée
const double _rowHPadding = 40 * 2;
// Espacement entre tuiles
const double _tileSpacing = 16;

double _tileWidth(BuildContext context) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final available = screenWidth - _rowHPadding - (_tileSpacing * (_tilesVisible - 1));
  return (available / _tilesVisible).clamp(200.0, 380.0);
}

/// Rangée horizontale défilante style Netflix pour Android TV.
class TvContentRow extends ConsumerWidget {
  final String title;
  final List<Media> items;
  final bool withResume;
  final void Function(Media)? onFocused;
  final bool autofocusFirst;

  const TvContentRow({
    super.key,
    required this.title,
    required this.items,
    this.withResume = false,
    this.onFocused,
    this.autofocusFirst = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final tileW = _tileWidth(context);
    final tileH = tileW / _tileAspectRatio;
    const focusMargin = 20.0;
    final rowH = tileH + focusMargin * 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 6),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(
            height: rowH,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemCount: items.length,
              itemBuilder: (context, i) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TvTile(
                    media: items[i],
                    tileWidth: tileW,
                    tileHeight: tileH,
                    withResume: withResume,
                    onFocused: onFocused,
                    autofocus: autofocusFirst && i == 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvTile extends ConsumerWidget {
  final Media media;
  final double tileWidth;
  final double tileHeight;
  final bool withResume;
  final void Function(Media)? onFocused;
  final bool autofocus;

  const _TvTile({
    required this.media,
    required this.tileWidth,
    required this.tileHeight,
    required this.withResume,
    this.onFocused,
    this.autofocus = false,
  });

  String get _displayTitle {
    if (media.animeSamaTitle != null && media.animeSamaTitle!.trim().isNotEmpty) {
      return media.animeSamaTitle!;
    }
    if (media.title.preferred.isNotEmpty) {
      return media.title.preferred;
    }
    return media.animeSamaSlug ?? 'Anime #${media.mediaId}';
  }

  void _open(BuildContext context, WidgetRef ref) {
    if (withResume) {
      resumePlayback(context, ref, media);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaDetailPageTv(
          mediaId: media.mediaId,
          displayTitle: _displayTitle,
          animeSamaSlug: media.animeSamaSlug,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: TvFocusable(
        autofocus: autofocus,
        onPressed: () => _open(context, ref),
        onFocused: () => onFocused?.call(media),
        child: GestureDetector(
          onTap: () => _open(context, ref),
          child: SizedBox(
            width: tileWidth,
            height: tileHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimeSamaImage(
                    key: ValueKey(media.mediaId),
                    slug: media.animeSamaSlug ?? '',
                    fallbackUrl: media.bannerUrl ?? media.coverUrl,
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.4, 1.0],
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: Text(
                      _displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (withResume)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
