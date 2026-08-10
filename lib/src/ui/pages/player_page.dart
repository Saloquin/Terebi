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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/media.dart' as domain;
import '../../domain/season_progress_repository.dart';
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

  /// Index de saison anime-sama courant (résolu au 1er `_prepareMeta`).
  int _seasonIndex = 1;

  /// `true` une fois l'épisode initial calculé (dernier vu + 1), pour ne le
  /// faire qu'une seule fois (à l'arrivée).
  bool _initialEpisodeResolved = false;

  /// Garde de réentrance pour la navigation d'épisode (`<`/`>`/menu) : évite un
  /// double marquage « vu » si l'utilisateur clique vite.
  bool _navigating = false;

  // --- Suivi de position (reprise) + auto-play -------------------------------

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;

  /// Position et durée courantes (secondes) observées du lecteur.
  double _positionSeconds = 0;
  double? _durationSeconds;

  /// Dernière position persistée (pour throttler l'écriture DB ~1×/5 s).
  int _lastPersistedWhole = -1;

  /// Compte à rebours d'auto-play (secondes restantes), null si inactif.
  int? _autoPlayCountdown;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentEntry = widget.entry;
    _configurePlayer();
    _subscribePlayerStreams();
    // La lecture ne démarre PAS automatiquement : l'utilisateur clique « Lancer ».
    // On charge tout de même le nom de saison + la liste d'épisodes pour la barre.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareMeta());
  }

  /// S'abonne aux flux du lecteur : position (reprise), durée, fin d'épisode
  /// (auto-play). Best-effort : sur desktop media_kit émet ces flux.
  void _subscribePlayerStreams() {
    _positionSub = _player.stream.position.listen((pos) {
      _positionSeconds = pos.inMilliseconds / 1000.0;
      _maybePersistPosition();
    });
    _durationSub = _player.stream.duration.listen((dur) {
      final s = dur.inMilliseconds / 1000.0;
      _durationSeconds = s > 0 ? s : null;
    });
    _completedSub = _player.stream.completed.listen((done) {
      if (done) _onEpisodeCompleted();
    });
  }

  /// Charge (sans lancer la vidéo) le nom de saison + la liste des épisodes,
  /// et calcule l'épisode initial = **dernier vu de la saison + 1** (borné).
  Future<void> _prepareMeta() async {
    if (!await _isAnimeSamaActive()) return;
    _seasonIndex = await _storedSeasonIndex();
    await _loadSeasonMeta(seasonIndex: _seasonIndex);

    // Épisode initial : reprendre à (dernier vu de la saison) + 1.
    if (!_initialEpisodeResolved) {
      _initialEpisodeResolved = true;
      final seasonProgress = ref.read(seasonProgressRepositoryProvider);
      final lastWatched =
          await seasonProgress.lastWatched(widget.media.anilistId, _seasonIndex);
      // La saison peut avoir été marquée « entièrement vue » via la sentinelle
      // (« Terminé » manuel) : lastWatched est alors artificiellement énorme.
      // On ne fait JAMAIS sentinelle+1 (numéro d'épisode absurde qui polluerait
      // ensuite entry.progress et les stats) : on repart au dernier épisode réel
      // connu, ou à 1 si la liste est inconnue.
      final markedFull =
          lastWatched >= SeasonProgressRepository.fullyWatchedSentinel;
      int target;
      if (markedFull) {
        target = _episodes.isNotEmpty ? _episodes.last : 1;
      } else {
        target = lastWatched + 1;
        if (_episodes.isNotEmpty && target > _episodes.last) {
          target = _episodes.last;
        }
      }
      _currentEpisode = target;
    }
    if (mounted) setState(() {});
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
      // Seek par keyframes : après un seek (reprise), mpv se cale sur l'image
      // clé la plus proche → l'image s'affiche tout de suite. Sans ça, un seek
      // « exact » peut donner du son sans image (attente de la prochaine
      // keyframe), surtout sur les flux HLS.
      platform.setProperty('hr-seek', 'no');
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    // Persiste la dernière position connue (reprise ultérieure). Fire-and-forget.
    _persistPosition();
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
  Future<int> _storedSeasonIndex() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final key = SettingsKeys.animeSamaSeasonFor(widget.media.anilistId);
    final stored = await settingsRepo.get(key);
    return (stored != null ? int.tryParse(stored) : null) ?? 1;
  }

  /// Résout l'URL via le résolveur actif et l'ouvre dans le lecteur encastré.
  Future<void> _loadAndPlay() async {
    if (_loading) return; // garde de réentrance : évite un double « Lancer ».
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final language = await _preferredLanguage();
      final isAnimeSama = await _isAnimeSamaActive();

      int seasonIndex = 1;
      if (isAnimeSama) {
        seasonIndex = await _storedSeasonIndex();
        _seasonIndex = seasonIndex;
        // Charge (best-effort) le nom de la saison + la liste des épisodes.
        await _loadSeasonMeta(seasonIndex: seasonIndex);

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

      // Reprise : si une position a été enregistrée pour cet épisode (non vu),
      // proposer « Reprendre » / « Recommencer » avant de démarrer.
      final resumeFrom = await _resumePositionSeconds();

      // Ouvre SANS jouer : on doit d'abord attendre que le flux soit prêt
      // (durée connue) avant de pouvoir seek de façon fiable, sinon mpv
      // repositionne à 0 au moment où le flux se charge réellement.
      await _player.open(Media(url), play: resumeFrom == null);

      if (resumeFrom != null && resumeFrom > 0) {
        await _seekThenPlay(Duration(seconds: resumeFrom));
      } else if (resumeFrom == 0) {
        // « Recommencer » explicite : on démarre au début.
        await _player.play();
      }

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
  ///
  /// Passe par les providers **globaux** (`animeSamaSeasonsProvider` /
  /// `animeSamaEpisodesProvider`), en utilisant le MÊME titre que la fiche
  /// (`animeSamaTitle` si connu) pour réutiliser le cache Riverpod et éviter de
  /// relancer le wrapper Python. Note : ces providers listent en VOSTFR ; la
  /// résolution du flux (`resolveStreamUrl`) respecte bien la langue choisie.
  Future<void> _loadSeasonMeta({
    required int seasonIndex,
  }) async {
    final title = widget.animeSamaTitle ?? widget.media.title.preferred;
    try {
      // Nom de la saison (une seule fois, si pas encore connu).
      if (_seasonName == null) {
        try {
          final seasons =
              await ref.read(animeSamaSeasonsProvider(title).future);
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
      final eps = await ref.read(animeSamaEpisodesProvider(
        (title: title, seasonIndex: seasonIndex),
      ).future);
      if (eps.isNotEmpty) _episodes = eps;
    } catch (_) {
      // listSeasons/listEpisodes optionnels : on continue sans.
    }
  }

  /// Marque l'épisode courant comme vu et fait avancer la progression.
  /// Met à jour la progression PAR SAISON (compteur N/total) et la progression
  /// globale (EpisodeProgress + entry) pour la cohérence avec la bibliothèque.
  Future<void> _markCurrentWatched() async {
    // Progression par saison anime-sama (pour la barre N/total sur la fiche).
    await ref.read(seasonProgressRepositoryProvider).markWatched(
          widget.media.anilistId,
          _seasonIndex,
          _currentEpisode,
        );

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
  }

  /// Recul appliqué à la reprise pour se remettre dans l'action (secondes).
  static const int _resumeRewindSeconds = 10;

  /// Position de reprise pour l'épisode courant, ou `null` pour démarrer au
  /// début. Si une position significative (> 30 s, épisode non terminé) est
  /// enregistrée, demande à l'utilisateur « Reprendre » ou « Recommencer ».
  /// La reprise recule de [_resumeRewindSeconds] pour ne pas reprendre pile à
  /// l'endroit d'arrêt. Retourne : position (>0) pour reprendre, 0 pour
  /// recommencer explicitement, `null` si rien à proposer.
  Future<int?> _resumePositionSeconds() async {
    EpisodeProgress? prog;
    try {
      prog = await ref
          .read(progressRepositoryProvider)
          .getProgress(widget.media.anilistId, _currentEpisode.toDouble());
    } catch (_) {
      return null;
    }
    if (prog == null || prog.watched) return null;
    final pos = prog.positionSeconds.floor();
    if (pos < 30) return null; // trop peu → démarrage normal
    if (!mounted) return null;

    final resume = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reprendre la lecture ?'),
        content: Text(
            'Épisode $_currentEpisode interrompu à ${_formatDuration(pos)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Recommencer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
    if (resume != true) return 0; // recommencer (ou dialogue fermé)
    // Recul pour se remettre dans l'action, borné à 0.
    final rewound = pos - _resumeRewindSeconds;
    return rewound > 0 ? rewound : 0;
  }

  /// Attend que le flux soit réellement prêt (durée connue), démarre la lecture
  /// PUIS seek. Ordre important : jouer d'abord active le décodeur vidéo, donc
  /// le seek qui suit affiche l'image (sinon on peut avoir le son sans image).
  /// Timeout de sécurité pour ne jamais bloquer.
  Future<void> _seekThenPlay(Duration target) async {
    try {
      // Attend la première durée > 0 (flux prêt), max 8 s.
      await _player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 8), onTimeout: () => Duration.zero);
      await _player.play();
      // Laisse le décodeur démarrer une image avant de sauter au timecode.
      await Future.delayed(const Duration(milliseconds: 150));
      await _player.seek(target);
    } catch (_) {
      // En dernier recours : au moins démarrer la lecture.
      try {
        await _player.play();
      } catch (_) {/* ignore */}
    }
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Persiste la position toutes les ~5 s de lecture (throttle) pour permettre
  /// la reprise, sans marteler la base.
  void _maybePersistPosition() {
    final whole = _positionSeconds.floor();
    if (whole == _lastPersistedWhole) return;
    if (whole % 5 != 0) return; // écrit ~1×/5 s
    _lastPersistedWhole = whole;
    _persistPosition();
  }

  /// Écrit la position courante dans EpisodeProgress (sans marquer « vu »).
  /// Ignore les positions triviales (< 5 s) et les fins d'épisode (gérées par
  /// _markCurrentWatched). Fire-and-forget.
  Future<void> _persistPosition() async {
    if (_positionSeconds < 5) return;
    // Proche de la fin (>95 %) → ne pas enregistrer une reprise « presque finie ».
    final dur = _durationSeconds;
    if (dur != null && dur > 0 && _positionSeconds / dur > 0.95) return;
    try {
      await ref.read(progressRepositoryProvider).upsertProgress(EpisodeProgress(
            mediaId: widget.media.anilistId,
            episodeNumber: _currentEpisode.toDouble(),
            watched: false,
            positionSeconds: _positionSeconds,
            durationSeconds: dur,
            updatedAt: DateTime.now(),
          ));
    } catch (_) {/* best-effort */}
  }

  /// Fin d'épisode atteinte : marque vu, remet la position à 0, et lance
  /// l'auto-play si activé dans les réglages et qu'un épisode suivant existe.
  Future<void> _onEpisodeCompleted() async {
    await _markCurrentWatched();
    _positionSeconds = 0;
    _lastPersistedWhole = -1;

    final autoPlay = await _autoPlayEnabled();
    final next = _nextEpisode;
    if (!autoPlay || next == null) {
      if (mounted) setState(() {});
      return;
    }
    _startAutoPlayCountdown(next);
  }

  Future<bool> _autoPlayEnabled() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .get(SettingsKeys.autoPlayNext);
    return v == '1';
  }

  /// Compte à rebours avant l'épisode suivant (annulable par l'utilisateur).
  void _startAutoPlayCountdown(int next) {
    _autoPlayTimer?.cancel();
    setState(() => _autoPlayCountdown = 5);
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = (_autoPlayCountdown ?? 1) - 1;
      if (remaining <= 0) {
        t.cancel();
        setState(() => _autoPlayCountdown = null);
        await _goToEpisode(next);
        if (mounted) await _loadAndPlay();
      } else {
        setState(() => _autoPlayCountdown = remaining);
      }
    });
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    setState(() => _autoPlayCountdown = null);
  }

  /// Navigue vers un épisode. Avancer marque l'épisode courant comme vu ;
  /// reculer ne modifie pas la progression. Ne lance PAS la lecture : le
  /// bouton « Lancer » réapparaît pour le nouvel épisode.
  Future<void> _goToEpisode(int ep) async {
    if (ep == _currentEpisode) return;
    if (_navigating) return; // garde : évite un double marquage si clics rapides.
    _navigating = true;
    _autoPlayTimer?.cancel();
    _autoPlayCountdown = null;
    try {
      if (ep > _currentEpisode) {
        await _markCurrentWatched();
      } else {
        // Recul : on ne marque pas vu, mais on sauvegarde la position de
        // l'épisode qu'on quitte pour pouvoir le reprendre plus tard.
        await _persistPosition();
      }
      if (!mounted) return;
      // Nouvel épisode → position remise à zéro.
      _positionSeconds = 0;
      _lastPersistedWhole = -1;
      setState(() {
        _currentEpisode = ep;
        _ready = false;
        _error = null;
      });
      await _player.stop();
    } finally {
      _navigating = false;
    }
  }

  /// Valide la fin de saison : marque le dernier épisode vu (compteur = total).
  Future<void> _finishSeason() async {
    await _markCurrentWatched();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saison terminée ! 🎉')),
    );
    setState(() {}); // rafraîchit l'état des boutons.
  }

  /// `true` si l'épisode courant est le dernier de la saison.
  bool get _isLastEpisode =>
      _episodes.isNotEmpty && _currentEpisode >= _episodes.last;

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
                        // Overlay auto-play : « Épisode suivant dans N… ».
                        if (_autoPlayCountdown != null)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Épisode suivant dans $_autoPlayCountdown…',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 18),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: _cancelAutoPlay,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white70),
                                      ),
                                      child: const Text('Annuler'),
                                    ),
                                  ],
                                ),
                              ),
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
                  isLastEpisode: _isLastEpisode,
                  onFinish: _finishSeason,
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
  final bool isLastEpisode;
  final VoidCallback onFinish;

  const _ControlBar({
    required this.seasonName,
    required this.currentEpisode,
    required this.episodes,
    required this.enabled,
    required this.onOpenDetail,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
    required this.isLastEpisode,
    required this.onFinish,
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
              Icon(Icons.layers_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  seasonName ?? 'Saison…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
        // Dernier épisode → bouton ✓ « valider fin de saison ».
        // Sinon → flèche « épisode suivant ».
        if (isLastEpisode)
          IconButton(
            icon: const Icon(Icons.check_circle),
            color: Colors.green,
            tooltip: 'Valider : saison terminée',
            onPressed: enabled ? onFinish : null,
          )
        else
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Épisode suivant',
            onPressed: enabled ? onNext : null,
          ),
      ],
    );
  }
}
