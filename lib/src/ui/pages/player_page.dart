/// Page lecteur — résout l'URL du flux via le résolveur actif (anime-sama ou
/// ani-cli) et la joue dans le lecteur **media_kit encastré**.
///
/// Comportement (retours utilisateur) :
/// - On arrive avec une **saison** (mémorisée pour ce média, défaut index 1 ;
///   le choix de saison se fait UNIQUEMENT sur la fiche) et un **épisode** déjà
///   sélectionnés (le dernier épisode vu, passé par l'appelant).
/// - La lecture démarre automatiquement au premier affichage.
/// - Sous la vidéo : une barre de contrôle avec le **nom de la saison** + un
///   bouton vers la **fiche**, et une navigation d'épisode **`<` / menu
///   déroulant (épisode courant) / `>`**.
/// - Avancer (`>` ou choix d'un épisode supérieur) marque l'épisode courant vu
///   (règle « épisode suivant ») ; reculer ne modifie pas la progression.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/media.dart' as domain;
import '../../services/stream_resolver.dart';
import 'media_detail_page.dart';

/// Page de lecture d'un épisode.
class PlayerPage extends ConsumerStatefulWidget {
  final domain.Media media;
  final int episode;
  final ListEntry entry;

  /// `true` si le lecteur a été ouvert DEPUIS la fiche : le bouton « fiche »
  /// revient alors à la fiche existante (pop) plutôt que d'en empiler une autre.
  /// `false` (défaut) quand on vient d'ailleurs (planning) : le bouton remplace
  /// le lecteur par la fiche (pushReplacement).
  final bool cameFromDetail;

  /// Titre propre anime-sama (ex. « Dr Stone »), transmis à la fiche pour
  /// l'afficher au lieu du titre AniList. `null` si inconnu.
  final String? animeSamaTitle;

  const PlayerPage({
    super.key,
    required this.media,
    required this.episode,
    required this.entry,
    this.cameFromDetail = false,
    this.animeSamaTitle,
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

  /// Épisodes disponibles pour la saison courante (anime-sama). Vide si inconnu
  /// ou si la source est ani-cli.
  List<int> _episodes = const [];

  /// Nom lisible de la saison courante (anime-sama), ou `null`.
  String? _seasonName;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentEntry = widget.entry;
    _configurePlayer();
    // La lecture ne démarre PAS automatiquement : l'utilisateur clique « Lancer ».
  }

  /// Configure mpv pour privilégier la MEILLEURE qualité disponible sur les
  /// flux HLS (.m3u8 multi-variantes) : par défaut mpv démarre sur une variante
  /// basse et adapte selon le débit. `hls-bitrate=max` force la variante la plus
  /// haute dès le départ. Sans effet sur les flux mono-qualité (mp4 Sibnet), où
  /// la résolution est fixée par le provider.
  void _configurePlayer() {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      // Best-effort : on n'attend pas, et on ignore une éventuelle erreur.
      platform.setProperty('hls-bitrate', 'max');
    }
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
    final langStr = await settingsRepo.get(SettingsKeys.playbackLanguage,
        defaultValue: 'vostfr');
    return langStr == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  }

  /// Détermine si la source active est anime-sama.
  Future<bool> _isAnimeSamaActive() async {
    final settings = ref.read(settingsRepositoryProvider);
    final source = await settings.get(SettingsKeys.streamSource,
        defaultValue: 'animesama');
    return source != 'ani_cli';
  }

  /// Index de saison mémorisé pour ce média, ou 1 par défaut.
  /// Le CHOIX de saison se fait sur la fiche (pas ici).
  Future<int> _seasonIndex() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final key = SettingsKeys.animeSamaSeasonFor(widget.media.anilistId);
    final stored = await settingsRepo.get(key);
    return (stored != null ? int.tryParse(stored) : null) ?? 1;
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
        seasonIndex = await _seasonIndex();
        // Charge (best-effort) le nom de la saison + la liste des épisodes.
        await _loadSeasonMeta(seasonIndex: seasonIndex, language: language);

        // Borne l'épisode courant à la liste connue.
        if (_episodes.isNotEmpty && _currentEpisode > _episodes.last) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error =
                'Épisode $_currentEpisode non disponible (max : ${_episodes.last}).';
          });
          return;
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

  /// Charge le nom de la saison et la liste des épisodes (anime-sama).
  /// Best-effort : en cas d'échec on garde les valeurs par défaut.
  Future<void> _loadSeasonMeta({
    required int seasonIndex,
    required PlaybackLanguage language,
  }) async {
    try {
      final resolver = await ref.read(animeSamaResolverProvider.future);
      final title = widget.media.title.preferred;

      // Nom de la saison (une seule fois, si pas encore connu).
      if (_seasonName == null) {
        try {
          final seasons = await resolver.listSeasons(
            title: title,
            language: language,
          );
          final match = seasons
              .where((s) => s.index == seasonIndex)
              .cast<AnimeSamaSeason?>()
              .firstWhere((_) => true, orElse: () => null);
          _seasonName = match?.name ?? 'Saison $seasonIndex';
        } catch (_) {
          _seasonName = 'Saison $seasonIndex';
        }
      }

      // Liste des épisodes de la saison.
      final eps = await resolver.listEpisodes(
        title: title,
        seasonIndex: seasonIndex,
        language: language,
      );
      if (eps.isNotEmpty) _episodes = eps;
    } catch (_) {
      // listSeasons/listEpisodes optionnels : on continue sans.
    }
  }

  /// Marque l'épisode courant comme vu et fait avancer la progression.
  /// Utilisé quand l'utilisateur passe à un épisode supérieur.
  Future<void> _markCurrentWatched() async {
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
    _currentEntry = outcome.updatedEntry;

    if (outcome.justCompleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Série terminée !')),
      );
    }
  }

  /// Navigue vers un épisode. Avancer marque l'épisode courant comme vu ;
  /// reculer ne modifie pas la progression.
  Future<void> _goToEpisode(int ep) async {
    if (ep == _currentEpisode) return;
    if (ep > _currentEpisode) {
      await _markCurrentWatched();
    }
    if (!mounted) return;
    setState(() {
      _currentEpisode = ep;
      _ready = false;
      _error = null;
    });
    await _loadAndPlay();
  }

  /// Épisode précédent dans [_episodes], ou `null` si on est au premier.
  int? get _prevEpisode {
    if (_episodes.isEmpty) {
      return _currentEpisode > 1 ? _currentEpisode - 1 : null;
    }
    final idx = _episodes.indexOf(_currentEpisode);
    if (idx > 0) return _episodes[idx - 1];
    return null;
  }

  /// Épisode suivant dans [_episodes], ou `null` si on est au dernier.
  int? get _nextEpisode {
    if (_episodes.isEmpty) {
      // Sans liste connue, on autorise toujours l'avance (borne serveur).
      return _currentEpisode + 1;
    }
    final idx = _episodes.indexOf(_currentEpisode);
    if (idx >= 0 && idx < _episodes.length - 1) return _episodes[idx + 1];
    return null;
  }

  void _openDetail() {
    // Dans tous les cas, quitter le lecteur le dispose → _player.dispose()
    // stoppe la lecture (pas de vidéo qui continue derrière la fiche).
    if (widget.cameFromDetail && Navigator.canPop(context)) {
      // On venait de la fiche : y revenir sans en empiler une seconde.
      Navigator.pop(context);
    } else {
      // On venait d'ailleurs (planning…) : remplacer le lecteur par la fiche.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MediaDetailPage(
            anilistId: widget.media.anilistId,
            displayTitle: widget.animeSamaTitle,
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = widget.media.title.preferred;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
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
                          Center(
                            child: FilledButton.icon(
                              onPressed: _loadAndPlay,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Lancer'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Barre de contrôle : saison + fiche | < menu > ---
                _ControlBar(
                  seasonName: _seasonName,
                  currentEpisode: _currentEpisode,
                  episodes: _episodes,
                  enabled: !_loading,
                  onOpenDetail: _openDetail,
                  onPrev: _prevEpisode != null
                      ? () => _goToEpisode(_prevEpisode!)
                      : null,
                  onNext: _nextEpisode != null
                      ? () => _goToEpisode(_nextEpisode!)
                      : null,
                  onSelect: (ep) => _goToEpisode(ep),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _loadAndPlay,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Barre de contrôle (saison + fiche | navigation d'épisode)
// ---------------------------------------------------------------------------

class _ControlBar extends StatelessWidget {
  final String? seasonName;
  final int currentEpisode;
  final List<int> episodes;
  final bool enabled;
  final VoidCallback onOpenDetail;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onSelect;

  const _ControlBar({
    required this.seasonName,
    required this.currentEpisode,
    required this.episodes,
    required this.enabled,
    required this.onOpenDetail,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Le menu déroulant a besoin que la valeur courante figure dans les items.
    final items = <int>[
      if (!episodes.contains(currentEpisode)) currentEpisode,
      ...episodes,
    ]..sort();

    return Row(
      children: [
        // --- Nom de la saison + accès fiche ---
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  seasonName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Fiche de l\'anime',
                onPressed: onOpenDetail,
              ),
            ],
          ),
        ),

        // --- Navigation d'épisode : < menu > ---
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Épisode précédent',
          onPressed: enabled ? onPrev : null,
        ),
        DropdownButton<int>(
          value: currentEpisode,
          underline: const SizedBox.shrink(),
          onChanged: enabled
              ? (ep) {
                  if (ep != null) onSelect(ep);
                }
              : null,
          items: [
            for (final ep in items)
              DropdownMenuItem(value: ep, child: Text('Épisode $ep')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Épisode suivant',
          onPressed: enabled ? onNext : null,
        ),
      ],
    );
  }
}
