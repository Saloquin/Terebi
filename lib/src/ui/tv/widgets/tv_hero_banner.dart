library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/media.dart';
import '../../pages/resume_helper.dart';
import '../../widgets/anime_sama_image.dart';
import '../../widgets/tv_focusable.dart';
import '../media_detail_page_tv.dart';

/// Hero Banner grand écran style Netflix / Apple TV pour Android TV.
/// Comporte un bouton d'action principal « Reprendre / Regarder » et un bouton « Détails ».
class TvHeroBanner extends ConsumerWidget {
  final Media media;
  final bool autofocus;

  const TvHeroBanner({
    super.key,
    required this.media,
    this.autofocus = true,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaDetailPageTv(
        mediaId: media.mediaId,
        displayTitle: media.animeSamaTitle ?? media.title.preferred,
        animeSamaSlug: media.animeSamaSlug,
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = media.animeSamaTitle ?? media.title.preferred;
    final bannerHeight = MediaQuery.sizeOf(context).height * 0.58;

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image d'arrière-plan avec fallback
          AnimeSamaImage(
            key: ValueKey(media.mediaId),
            slug: media.animeSamaSlug ?? '',
            fallbackUrl: media.bannerUrl ?? media.coverUrl,
            fit: BoxFit.cover,
          ),
          // Dégradé sombre pour lisibilité TV (gauche & bas)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.black.withValues(alpha: 0.70),
                  Colors.black.withValues(alpha: 0.20),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.6, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 1.0),
                ],
              ),
            ),
          ),

          // Contenu textuel et boutons télécommande
          Positioned(
            left: 48,
            bottom: 32,
            right: MediaQuery.sizeOf(context).width * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge catégorie / statut
                if (media.genres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            media.genres.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (media.genres.length > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            media.genres.skip(1).take(2).join(' • '),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Titre principal
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(blurRadius: 12, color: Colors.black87),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Synopsis
                if (media.description != null && media.description!.trim().isNotEmpty)
                  Text(
                    media.description!.replaceAll(RegExp(r'<[^>]*>'), ''),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.35,
                      shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 20),

                // Boutons d'action focusables pour télécommande
                Row(
                  children: [
                    TvFocusable(
                      autofocus: autofocus,
                      onPressed: () => resumePlayback(context, ref, media),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                            SizedBox(width: 8),
                            Text(
                              'Regarder',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TvFocusable(
                      onPressed: () => _openDetail(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Fiche & Épisodes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
