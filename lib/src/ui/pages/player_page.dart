/// Page lecteur — résout l'URL du flux via le résolveur actif (anime-sama ou
/// ani-cli) et la joue dans le lecteur **media_kit encastré**, avec la règle
/// « Épisode suivant » (markCurrentWatchedAndAdvance).
///
/// Flux :
/// 1. Si la source est anime-sama et aucune saison mémorisée : affiche un dialog
///    de sélection de saison → mémorise l'index choisi via SettingsRepository.
/// 2. [activeResolverProvider.resolveStreamUrl] → URL directe du flux HLS.
/// 3. media_kit ([Player]/[VideoController]) ouvre cette URL → vidéo encastrée.
/// 4. Fallback : si la résolution échoue, affiche le message d'erreur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/media.dart' as domain;
import '../../services/stream_resolver.dart';

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

  /// Détermine si la source active est anime-sama.
  Future<bool> _isAnimeSamaActive() async {
    final settings = ref.read(settingsRepositoryProvider);
    final source =
        await settings.get('stream_source', defaultValue: 'animesama');
    return source != 'ani_cli';
  }

  /// Retourne l'index de saison mémorisé, ou le demande via un dialog.
  /// Retourne `null` si l'utilisateur annule.
  Future<int?> _resolveSeasonIndex({required PlaybackLanguage language}) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final key = 'anime_sama_season:${widget.media.anilistId}';

    // Saison déjà mémorisée ?
    final stored = await settingsRepo.get(key);
    if (stored != null) {
      final parsed = int.tryParse(stored);
      if (parsed != null) return parsed;
    }

    // Pas encore mémorisée : charger les saisons et afficher le sélecteur.
    if (!mounted) return null;

    List<AnimeSamaSeason> seasons;
    try {
      final resolver = await ref.read(animeSamaResolverProvider.future);
      seasons = await resolver.listSeasons(
        title: widget.media.title.preferred,
        language: language,
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lister les saisons : $e')),
      );
      return null;
    }

    if (!mounted) return null;

    // Si une seule saison, pas besoin de dialog.
    if (seasons.length == 1) {
      await settingsRepo.set(key, '${seasons.first.index}');
      return seasons.first.index;
    }

    final chosen = await showDialog<AnimeSamaSeason>(
      context: context,
      builder: (ctx) => _SeasonPickerDialog(seasons: seasons),
    );
    if (chosen == null) return null;

    await settingsRepo.set(key, '${chosen.index}');
    return chosen.index;
  }

  /// Résout l'URL via le résolveur actif et l'ouvre dans le lecteur encastré.
  Future<void> _loadAndPlay() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final language = await _preferredLanguage();
      final isAnimeSama = await _isAnimeSamaActive();

      int seasonIndex = 1;
      if (isAnimeSama) {
        final idx = await _resolveSeasonIndex(language: language);
        if (idx == null) {
          // Utilisateur a annulé.
          setState(() => _loading = false);
          return;
        }
        seasonIndex = idx;
      }

      // Borne l'épisode via listEpisodes si anime-sama.
      if (isAnimeSama) {
        try {
          final resolver = await ref.read(animeSamaResolverProvider.future);
          final eps = await resolver.listEpisodes(
            title: widget.media.title.preferred,
            seasonIndex: seasonIndex,
            language: language,
          );
          if (eps.isNotEmpty && _currentEpisode > eps.last) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = 'Épisode $_currentEpisode non disponible (max : ${eps.last}).';
            });
            return;
          }
        } catch (_) {
          // listEpisodes optionnel : on continue si ça échoue.
        }
      }

      final resolver = await ref.read(activeResolverProvider.future);
      final url = await resolver.resolveStreamUrl(
        title: widget.media.title.preferred,
        episode: _currentEpisode,
        season: seasonIndex,
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

  /// Ré-affiche le sélecteur de saison, mémorise le nouveau choix et recharge.
  Future<void> _changeSeason() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final key = 'anime_sama_season:${widget.media.anilistId}';
    // Efface la saison mémorisée pour forcer le re-sélecteur.
    await settingsRepo.delete(key);
    setState(() {
      _ready = false;
      _error = null;
    });
    await _loadAndPlay();
  }

  /// Applique la règle « Épisode suivant » : marque vu + progress++, persiste,
  /// puis charge l'épisode suivant s'il existe (ou termine si saison complète).
  Future<void> _onNextEpisode() async {
    // Si anime-sama : vérifie la borne max de la saison courante.
    final isAnimeSama = await _isAnimeSamaActive();
    if (isAnimeSama) {
      try {
        final language = await _preferredLanguage();
        final settingsRepo = ref.read(settingsRepositoryProvider);
        final key = 'anime_sama_season:${widget.media.anilistId}';
        final stored = await settingsRepo.get(key);
        final seasonIndex = (stored != null ? int.tryParse(stored) : null) ?? 1;

        final resolver = await ref.read(animeSamaResolverProvider.future);
        final eps = await resolver.listEpisodes(
          title: widget.media.title.preferred,
          seasonIndex: seasonIndex,
          language: language,
        );
        if (eps.isNotEmpty && _currentEpisode >= eps.last) {
          // Dernier épisode de la saison atteint : on traite comme fin de série.
          await _markWatched();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saison terminée !')),
          );
          Navigator.of(context).pop();
          return;
        }
      } catch (_) {
        // En cas d'erreur listEpisodes, on laisse la logique standard.
      }
    }

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

  /// Marque l'épisode courant comme vu sans avancer (utilisé en fin de saison
  /// anime-sama quand la borne max est atteinte).
  Future<void> _markWatched() async {
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
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _loading ? null : _changeSeason,
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: const Text('Changer de saison'),
                    ),
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

// ---------------------------------------------------------------------------
// Dialog de sélection de saison
// ---------------------------------------------------------------------------

class _SeasonPickerDialog extends StatelessWidget {
  final List<AnimeSamaSeason> seasons;

  const _SeasonPickerDialog({required this.seasons});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir la saison'),
      content: SizedBox(
        width: double.minPositive,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: seasons.length,
          itemBuilder: (ctx, i) {
            final s = seasons[i];
            return ListTile(
              title: Text(s.name),
              onTap: () => Navigator.of(ctx).pop(s),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
