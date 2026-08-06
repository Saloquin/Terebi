/// Page lecteur — lance un épisode via ani-cli et gère la règle
/// « Épisode suivant » (markCurrentWatchedAndAdvance).
///
/// Décision d'architecture (MVP) :
/// ani-cli résout lui-même la source et ouvre mpv en externe — il ne fournit
/// pas d'URL directe de façon fiable sans spike US-00 (flags --json / --get-url
/// à confirmer avec le vrai binaire). Le widget [Video] de media_kit est donc
/// préparé dans la page pour l'encastrement futur mais la lecture réelle passe
/// par [AniCliResolver.play], qui délègue à ani-cli/mpv.
///
/// TODO (US-00) : une fois les flags ani-cli confirmés, remplacer l'appel
/// [resolver.play] par une résolution d'URL puis [player.open(Media(url))].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/media.dart';
import '../../domain/models/episode_progress.dart';
import '../../services/ani_cli_resolver.dart';

/// Page de lecture d'un épisode.
///
/// [media]          : métadonnées du titre.
/// [episode]        : numéro d'épisode à lire (1-based).
/// [entry]          : entrée de liste courante (pour progression).
class PlayerPage extends ConsumerStatefulWidget {
  final Media media;
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
  bool _launching = false;
  bool _launched = false;
  String? _error;

  // Épisode courant (peut changer quand l'utilisateur clique « Épisode suivant »)
  late int _currentEpisode;
  late ListEntry _currentEntry;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentEntry = widget.entry;
  }

  // ---------------------------------------------------------------------------
  // Logique métier
  // ---------------------------------------------------------------------------

  Future<void> _launch() async {
    setState(() {
      _launching = true;
      _error = null;
    });

    try {
      final resolver = await ref.read(aniCliResolverProvider.future);
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final langStr = await settingsRepo.get(
        'playback_language',
        defaultValue: 'vostfr',
      );
      final language = langStr == 'vf'
          ? PlaybackLanguage.vf
          : PlaybackLanguage.vostfr;

      await resolver.play(
        title: widget.media.title.preferred,
        episode: _currentEpisode,
        language: language,
      );

      setState(() {
        _launched = true;
        _launching = false;
      });
    } on ResolveException catch (e) {
      setState(() {
        _error = e.message;
        _launching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _launching = false;
      });
    }
  }

  /// Applique la règle « Épisode suivant » (ProgressService.markCurrentWatchedAndAdvance),
  /// persiste via listRepository + progressRepository, puis relance si un épisode
  /// suivant existe.
  Future<void> _onNextEpisode() async {
    final progressService = ref.read(progressServiceProvider);
    final listRepo = ref.read(listRepositoryProvider);
    final progressRepo = ref.read(progressRepositoryProvider);

    final outcome = progressService.markCurrentWatchedAndAdvance(
      entry: _currentEntry,
      media: widget.media,
      currentEpisode: _currentEpisode,
      now: DateTime.now(),
    );

    // Persiste l'entrée de liste mise à jour.
    await listRepo.upsertEntry(outcome.updatedEntry);

    // Persiste la progression d'épisode (marqué watched).
    await progressRepo.upsertProgress(EpisodeProgress(
      mediaId: widget.media.anilistId,
      episodeNumber: _currentEpisode.toDouble(),
      watched: true,
      positionSeconds: 0,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    if (!mounted) return;

    if (outcome.justCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Série terminée !')),
      );
    }

    if (outcome.nextEpisode != null) {
      // Relance l'épisode suivant.
      setState(() {
        _currentEpisode = outcome.nextEpisode!;
        _currentEntry = outcome.updatedEntry;
        _launched = false;
        _error = null;
      });
      await _launch();
    } else {
      // Pas d'épisode suivant : retour à la page précédente.
      if (mounted) Navigator.of(context).pop();
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Illustration placeholder (emplacement futur du widget Video) ---
                // TODO(US-00) : remplacer par Video(controller: _videoController)
                // une fois l'URL directe disponible via ani-cli --get-url.
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: _launched
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline,
                                    color: Colors.white54, size: 64),
                                SizedBox(height: 12),
                                Text(
                                  'Lecture en cours dans mpv',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            )
                          : const Icon(Icons.movie_outlined,
                              color: Colors.white24, size: 64),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- Titre + épisode ---
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Épisode $_currentEpisode'
                  '${totalEp != null ? ' sur $totalEp' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                // --- Erreur ---
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer,
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

                const SizedBox(height: 24),

                // --- Bouton principal : Lancer via ani-cli ---
                FilledButton.icon(
                  onPressed: _launching ? null : _launch,
                  icon: _launching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_launched
                      ? 'Relancer l\'épisode $_currentEpisode'
                      : 'Lancer via ani-cli'),
                ),

                // --- Bouton Épisode suivant (visible après lancement) ---
                if (_launched) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _launching ? null : _onNextEpisode,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Épisode suivant (marquer vu)'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
