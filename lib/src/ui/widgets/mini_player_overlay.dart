import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../services/active_playback_service.dart';
import '../pages/player_page.dart';

/// Widget flottant de mini-lecteur incrusté (In-App Picture-in-Picture).
///
/// Affiché en surimpression en bas à droite de l'application lorsque
/// l'utilisateur a réduit la lecture pour continuer à naviguer dans Terebi.
class MiniPlayerOverlay extends ConsumerStatefulWidget {
  const MiniPlayerOverlay({super.key});

  @override
  ConsumerState<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends ConsumerState<MiniPlayerOverlay> {
  bool _hovered = false;

  void _expand(BuildContext context, ActivePlaybackData data) {
    ActivePlaybackService.instance.clearWithoutDispose();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          media: data.media,
          episode: data.episode,
          entry: data.entry,
          animeSamaTitle: data.animeSamaTitle,
          existingPlayer: data.player,
          existingController: data.controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbackService = ref.watch(activePlaybackProvider);
    if (!playbackService.isMinimized || playbackService.current == null) {
      return const SizedBox.shrink();
    }

    final data = playbackService.current!;
    final theme = Theme.of(context);
    final title = data.media.title.preferred;

    return Positioned(
      bottom: 20,
      right: 20,
      width: 320,
      height: 180,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          elevation: 12,
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Flux vidéo
                Video(
                  controller: data.controller,
                  controls: NoVideoControls,
                ),

                // Détection de clic pour agrandir
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _expand(context, data),
                ),

                // Voile et contrôles au survol
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Barre supérieure : titre + fermer
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$title • Ép. ${data.episode}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 24, minHeight: 24),
                              tooltip: 'Fermer la vidéo',
                              onPressed: () =>
                                  ActivePlaybackService.instance.stop(),
                            ),
                          ],
                        ),

                        // Barre inférieure : agrandir + play/pause
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_full,
                                  size: 18, color: Colors.white),
                              tooltip: 'Agrandir en plein écran',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                              onPressed: () => _expand(context, data),
                            ),
                            StreamBuilder<bool>(
                              stream: data.player.stream.playing,
                              builder: (context, snapshot) {
                                final playing = snapshot.data ?? true;
                                return IconButton(
                                  icon: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                  tooltip: playing ? 'Pause' : 'Lecture',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  onPressed: () =>
                                      data.player.playOrPause(),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Ligne de progression au bas du mini-lecteur
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: StreamBuilder<Duration>(
                    stream: data.player.stream.position,
                    builder: (context, posSnap) {
                      final pos = posSnap.data?.inMilliseconds ?? 0;
                      final dur =
                          data.player.state.duration.inMilliseconds;
                      final progress = (dur > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        minHeight: 3,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
