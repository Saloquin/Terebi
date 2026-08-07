/// Page lecteur — résout l'URL du flux via ani-cli (mode debug, spike US-00)
/// et la joue dans le lecteur **media_kit encastré**, avec la règle
/// « Épisode suivant » (markCurrentWatchedAndAdvance).
///
/// Flux (spike US-00 validé) :
/// 1. [AniCliResolver.resolveStreamUrl] lance ani-cli avec `ANI_CLI_PLAYER=debug`
///    → récupère l'URL directe du flux HLS (.m3u8).
/// 2. media_kit ([Player]/[VideoController]) ouvre cette URL → vidéo encastrée
///    dans la page (widget [Video]) avec overlays maison.
/// 3. Fallback : si la résolution échoue, [AniCliResolver.play] laisse ani-cli
///    ouvrir son lecteur externe.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/media.dart' as domain;
import '../../services/ani_cli_resolver.dart';
import '../../services/stream_resolver.dart';
import '../../services/title_utils.dart';

/// Page de lecture d'un épisode.
class PlayerPage extends ConsumerStatefulWidget {
  final domain.Media media;
  final int episode;
  final ListEntry entry;

  const PlayerPage({
    super.key,
    required this.media,
    required this.episode,
    required this.entry,
  });

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  bool _loading = false;
  bool _ready = false;
  String? _error;

  late int _currentEpisode;
  late ListEntry _currentEntry;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentEntry = widget.entry;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logique métier
  // ---------------------------------------------------------------------------

  Future<PlaybackLanguage> _preferredLanguage() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final langStr =
        await settingsRepo.get('playback_language', defaultValue: 'vostfr');
    return langStr == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  }

  /// Résout l'URL via ani-cli (mode debug) et l'ouvre dans le lecteur encastré.
  Future<void> _loadAndPlay() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resolver = await ref.read(activeResolverProvider.future);
      final language = await _preferredLanguage();

      // Déduit le titre de base + n° de saison depuis le titre AniList
      // (ex. « Dr Stone Saison 2 » → base « Dr Stone », saison 2).
      final ts = parseSeasonFromTitle(widget.media.title.preferred);

      final url = await resolver.resolveStreamUrl(
        title: ts.baseTitle,
        episode: _currentEpisode,
        season: ts.season,
        language: language,
      );

      await _player.open(Media(url));

      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
    } on ResolveException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Applique la règle « Épisode suivant » : marque vu + progress++, persiste,
  /// puis charge l'épisode suivant s'il existe.
  Future<void> _onNextEpisode() async {
    final progressService = ref.read(progressServiceProvider);
    final listRepo = ref.read(listRepositoryProvider);
    final progressRepo = ref.read(progressRepositoryProvider);
    final now = DateTime.now();

    final outcome = progressService.markCurrentWatchedAndAdvance(
      entry: _currentEntry,
      media: widget.media,
      currentEpisode: _currentEpisode,
      now: now,
    );

    await listRepo.upsertEntry(outcome.updatedEntry);
    await progressRepo.upsertProgress(EpisodeProgress(
      mediaId: widget.media.anilistId,
      episodeNumber: _currentEpisode.toDouble(),
      watched: true,
      positionSeconds: 0,
      completedAt: now,
      updatedAt: now,
    ));

    if (!mounted) return;

    if (outcome.justCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Série terminée !')),
      );
    }

    if (outcome.nextEpisode != null) {
      setState(() {
        _currentEpisode = outcome.nextEpisode!;
        _currentEntry = outcome.updatedEntry;
        _ready = false;
        _error = null;
      });
      await _loadAndPlay();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = widget.media.title.preferred;
    final totalEp = widget.media.episodes;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$title — Épisode $_currentEpisode'
          '${totalEp != null ? ' / $totalEp' : ''}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Lecteur encastré media_kit ---
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.black),
                        if (_ready)
                          Video(controller: _videoController)
                        else if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else
                          const Center(
                            child: Icon(Icons.movie_outlined,
                                color: Colors.white24, size: 64),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Épisode $_currentEpisode'
                  '${totalEp != null ? ' sur $totalEp' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _loadAndPlay,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_ready ? 'Recharger' : 'Lancer l\'épisode'),
                    ),
                    if (_ready) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _onNextEpisode,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Épisode suivant'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
