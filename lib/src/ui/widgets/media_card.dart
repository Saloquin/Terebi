/// Widget réutilisable : carte d'un média (cover + titre + badge format/épisodes).
library;

import 'package:flutter/material.dart';

import '../../domain/models/media.dart';
import 'anime_sama_image.dart';

/// Carte compacte affichant la couverture, le titre préféré et un badge
/// format/épisodes. Utilisée dans la grille du Catalogue et du Planning.
class MediaCard extends StatelessWidget {
  final Media media;

  /// Rappel optionnel au tap (navigation vers la fiche détail).
  final VoidCallback? onTap;

  /// Rappel optionnel « Reprendre » : si fourni, un bouton play s'affiche en
  /// surimpression sur la cover (utilisé pour « Continuer à regarder »).
  final VoidCallback? onResume;

  const MediaCard({super.key, required this.media, this.onTap, this.onResume});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Cover image ---
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image dérivée du slug anime-sama (cascade d'extensions) dès
                  // qu'un slug est connu ; sinon fallback sur coverUrl legacy.
                  (media.animeSamaSlug != null &&
                          media.animeSamaSlug!.isNotEmpty)
                      ? AnimeSamaImage(
                          slug: media.animeSamaSlug!,
                          fallbackUrl: media.coverUrl,
                          fit: BoxFit.cover,
                        )
                      : media.coverUrl != null
                          ? Image.network(
                              media.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _CoverPlaceholder(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                            )
                          : _CoverPlaceholder(
                              color: colorScheme.surfaceContainerHighest,
                            ),
                  if (onResume != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          tooltip: 'Reprendre',
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          onPressed: onResume,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // --- Info bar ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title.preferred,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Badge nombre d'épisodes : masqué si inconnu (anime-sama ne
                  // fournit pas de compte global fiable pour toutes les fiches).
                  if (media.episodes != null) ...[
                    const SizedBox(height: 4),
                    _EpisodesBadge(episodes: media.episodes!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge compact montrant le nombre d'épisodes.
class _EpisodesBadge extends StatelessWidget {
  final int episodes;

  const _EpisodesBadge({required this.episodes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$episodes ep',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final Color color;
  const _CoverPlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}
