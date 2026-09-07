library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../widgets/anime_sama_image.dart';
import '../../widgets/tv_focusable.dart';
import '../../pages/media_detail_page.dart';
import '../../pages/resume_helper.dart';

// 170px tuile + 30px pour la bordure TvFocusable (3px×2) + AnimatedScale (×1.05) + espacement vertical.
const double _tileHeight = 170;
const double _rowHeight = _tileHeight + 30;

/// Rangée horizontale défilante style Netflix pour Android TV.
/// Tuiles 16:9 (300×170px). [onFocused] est appelé quand une tuile reçoit
/// le focus — permet au hero parent de changer son fond.
class TvContentRow extends ConsumerWidget {
  final String title;
  final List<Media> items;
  final bool withResume;
  final void Function(Media)? onFocused;

  const TvContentRow({
    super.key,
    required this.title,
    required this.items,
    this.withResume = false,
    this.onFocused,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: _rowHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              itemCount: items.length,
              itemBuilder: (context, i) => _TvTile(
                media: items[i],
                withResume: withResume,
                onFocused: onFocused,
                autofocus: i == 0,
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
  final bool withResume;
  final void Function(Media)? onFocused;
  final bool autofocus;

  const _TvTile({
    required this.media,
    required this.withResume,
    this.onFocused,
    this.autofocus = false,
  });

  void _open(BuildContext context, WidgetRef ref) {
    if (withResume) {
      resumePlayback(context, ref, media);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          mediaId: media.mediaId,
          displayTitle: media.title.preferred,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: TvFocusable(
        autofocus: autofocus,
        onPressed: () => _open(context, ref),
        onFocused: () => onFocused?.call(media),
        child: GestureDetector(
          onTap: () => _open(context, ref),
          child: SizedBox(
            width: 300,
            height: _tileHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover
                  AnimeSamaImage(
                    key: ValueKey(media.mediaId),
                    slug: media.animeSamaSlug ?? '',
                    fallbackUrl: media.coverUrl,
                    fit: BoxFit.cover,
                  ),
                  // Gradient bas
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1.0],
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // Titre en bas
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      media.title.preferred,
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
                  // Icône lecture si withResume
                  if (withResume)
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white70,
                        size: 40,
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
