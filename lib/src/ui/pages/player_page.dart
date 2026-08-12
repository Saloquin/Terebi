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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../domain/models/episode_progress.dart';
import '../../domain/models/list_entry.dart';
import '../../domain/models/list_status.dart';
import '../../domain/models/media.dart' as domain;
import '../../domain/season_progress_repository.dart';
import '../../services/stream_resolver.dart';
import 'library_page.dart';
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
  // Décodage LOGICIEL forcé (hwdec: 'no'). Le décodage matériel (d3d11va,
  // d3d11va-copy) produisait un flash vert + un saut automatique + une zone
  // injoignable sur certains flux HLS : le segment abîmé restait « brûlé » dans
  // la session jusqu'à réouverture de l'épisode. Le flash vert est un artefact
  // purement GPU ; le décodage logiciel l'élimine à la source (plus lourd CPU,
  // mais un épisode d'anime 1080p reste largement dans les capacités d'un PC).
  late final VideoController _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(hwdec: 'no'),
  );

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

  /// Clés du bouton « réglages » de la barre du player (ancrage du menu).
  /// DEUX clés distinctes : la barre normale et la barre plein écran sont
  /// montées SIMULTANÉMENT par media_kit ; partager une seule GlobalKey entre
  /// les deux lève « Multiple widgets used the same GlobalKey » (ce qui
  /// corrompt l'arbre et laisse le lecteur tourner en fantôme au dispose).
  final GlobalKey _settingsButtonKey = GlobalKey();
  final GlobalKey _settingsButtonKeyFs = GlobalKey();

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

  /// Seek relatif accumulé (cible en ms) + debounce, pour absorber les appuis
  /// rapides sur ←/→ sans réempiler des seeks sur une position pas encore
  /// stabilisée (sinon boucle/désync, surtout en recul).
  Duration? _seekTarget;
  Timer? _seekDebounce;

  /// Dernière position persistée (pour throttler l'écriture DB ~1×/5 s).
  int _lastPersistedWhole = -1;

  /// Compte à rebours d'auto-play (secondes restantes), null si inactif.
  int? _autoPlayCountdown;
  Timer? _autoPlayTimer;

  /// Vitesse de lecture courante (1.0 = normal).
  double _speed = 1.0;
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  /// Durées de saut (secondes) configurables dans les Paramètres.
  int _seekForward = 10;
  int _seekBackward = 10;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentEntry = widget.entry;
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
    _seasonIndex = await _storedSeasonIndex();
    // Résout la langue courante dès l'arrivée pour que le sélecteur l'affiche
    // (sinon aucune langue n'est marquée tant qu'on n'a pas cliqué « Lancer »).
    _language ??= await _preferredLanguage();
    final settings = ref.read(settingsRepositoryProvider);
    _singleLanguage =
        (await settings.get(SettingsKeys.singleLanguage, defaultValue: '0')) ==
            '1';
    _seekForward = int.tryParse(
            await settings.get(SettingsKeys.seekForwardSeconds,
                    defaultValue: '10') ??
                '10') ??
        10;
    _seekBackward = int.tryParse(
            await settings.get(SettingsKeys.seekBackwardSeconds,
                    defaultValue: '10') ??
                '10') ??
        10;
    if (mounted) setState(() {});
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

    // Détecte les langues dispo pour l'épisode initial (grise la langue absente
    // dans le sélecteur dès l'arrivée), sauf en mode « langue unique ».
    if (!_singleLanguage) {
      final title = widget.animeSamaTitle ?? widget.media.title.preferred;
      _refreshAvailableLangs(title, _seasonIndex, _currentEpisode);
    }
  }

  /// Applique les propriétés mpv sensibles au timing **après** l'ouverture d'un
  /// média (backend actif). Posées en initState, elles étaient ignorées ou
  /// écrasées par l'init de media_kit → comportement erratique du seek.
  ///
  /// - `hls-bitrate=max` : force la meilleure variante HLS dès le départ.
  /// - `hr-seek=yes` + `hr-seek-framedrop=no` : seek EXACT sans laisser tomber
  ///   de frames. Sans seek exact, mpv se cale sur les keyframes et la zone
  ///   entre deux keyframes devient injoignable (retour arrière qui re-saute
  ///   toujours au même point).
  /// - `vd-lavc-show-all=no` : ne pas afficher les frames décodées en erreur.
  /// - `demuxer-lavf-o=…reconnect…` : réessaie automatiquement un segment HLS
  ///   qui arrive mal (coupure réseau, segment tronqué) au lieu de le garder
  ///   corrompu — c'est ce recollage raté en session qui produisait le flash
  ///   vert + saut + zone injoignable jusqu'à réouverture.
  /// - back-buffer VOLONTAIREMENT modeste : garder 256 Mo de segments déjà lus
  ///   conservait aussi des segments mal recollés (le recul retombait dessus).
  ///   Un petit back-buffer force mpv à re-télécharger proprement.
  Future<void> _applyMpvProperties() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    Future<void> set(String k, String v) async {
      try {
        await platform.setProperty(k, v);
      } catch (_) {/* best-effort */}
    }

    await set('hls-bitrate', 'max');
    await set('hr-seek', 'yes');
    await set('hr-seek-framedrop', 'no');
    await set('vd-lavc-show-all', 'no');
    // Reconnexion/ré-essai ffmpeg sur les segments HLS interrompus ou tronqués.
    await set('demuxer-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
    // Back-buffer modeste (16 Mo) : recul récent OK, mais on ne conserve pas de
    // longs segments potentiellement mal recollés.
    await set('demuxer-max-back-bytes', '${16 * 1024 * 1024}');
    await set('demuxer-max-bytes', '${64 * 1024 * 1024}');
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _seekDebounce?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();

    // Capture les valeurs + le repository AVANT toute opération risquée.
    final pos = _positionSeconds;
    final dur = _durationSeconds;
    ProgressRepository? repo;
    try {
      repo = ref.read(progressRepositoryProvider);
    } catch (_) {
      repo = null; // ref indisponible pendant le teardown : on saute la sauvegarde.
    }

    // PRIORITÉ ABSOLUE : arrêter/disposer le player, quoi qu'il arrive, pour ne
    // jamais laisser une vidéo tourner en arrière-plan.
    _player.dispose();

    // Persistance best-effort APRÈS le dispose du player (ne bloque jamais la
    // fermeture, ne peut plus empêcher l'arrêt de la lecture).
    if (repo != null &&
        pos >= 5 &&
        !(dur != null && dur > 0 && pos / dur > 0.95)) {
      repo.upsertProgress(EpisodeProgress(
        mediaId: widget.media.anilistId,
        episodeNumber: _currentEpisode.toDouble(),
        watched: false,
        positionSeconds: pos,
        durationSeconds: dur,
        updatedAt: DateTime.now(),
      ));
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logique métier
  // ---------------------------------------------------------------------------

  /// Langue de lecture courante (choisie via le sélecteur, mémorisée par anime).
  /// Résolue au 1er chargement : préférence par anime, sinon réglage global.
  PlaybackLanguage? _language;

  /// Langues disponibles pour l'épisode courant (null tant que non testé).
  Set<PlaybackLanguage>? _availableLangs;

  /// `true` si le mode « langue unique » est actif (sélecteur masqué).
  bool _singleLanguage = false;

  /// Langue préférée : celle mémorisée pour CET anime si elle existe, sinon le
  /// réglage global.
  Future<PlaybackLanguage> _preferredLanguage() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final perAnime =
        await settingsRepo.get(SettingsKeys.animeSamaLangFor(widget.media.anilistId));
    if (perAnime == 'vf') return PlaybackLanguage.vf;
    if (perAnime == 'vostfr') return PlaybackLanguage.vostfr;
    final langStr = await settingsRepo.get(SettingsKeys.playbackLanguage,
        defaultValue: 'vostfr');
    return langStr == 'vf' ? PlaybackLanguage.vf : PlaybackLanguage.vostfr;
  }

  /// Mémorise la langue choisie POUR CET anime (prime sur le réglage global).
  Future<void> _persistLanguage(PlaybackLanguage lang) async {
    await ref.read(settingsRepositoryProvider).set(
          SettingsKeys.animeSamaLangFor(widget.media.anilistId),
          lang == PlaybackLanguage.vf ? 'vf' : 'vostfr',
        );
  }

  /// Teste (en tâche de fond) quelles langues existent pour l'épisode courant,
  /// puis met à jour le sélecteur (grise la langue absente).
  Future<void> _refreshAvailableLangs(
      String title, int seasonIndex, int episode) async {
    try {
      final langs = await ref.read(animeSamaLanguagesProvider(
        (title: title, seasonIndex: seasonIndex, episode: episode),
      ).future);
      if (mounted) setState(() => _availableLangs = langs);
    } catch (_) {/* ignore : sélecteur reste actif */}
  }

  /// Change la langue depuis le sélecteur.
  /// - Si la lecture n'est PAS encore lancée (bouton « Lancer » affiché) : on
  ///   mémorise seulement le choix, sans lancer — le clic « Lancer » proposera
  ///   alors la reprise normalement, dans la bonne langue.
  /// - Si la lecture est en cours : on relance l'épisode courant dans la
  ///   nouvelle langue en conservant le timecode.
  Future<void> _switchLanguage(PlaybackLanguage lang) async {
    if (lang == _language) return;
    _language = lang;
    await _persistLanguage(lang);

    // Épisode pas encore lancé → on ne fait que mémoriser + rafraîchir l'état.
    if (!_ready) {
      if (mounted) setState(() {});
      if (!_singleLanguage) {
        final title = widget.animeSamaTitle ?? widget.media.title.preferred;
        _refreshAvailableLangs(title, _seasonIndex, _currentEpisode);
      }
      return;
    }

    // Lecture en cours → relance au même timecode dans l'autre langue,
    // en conservant l'état pause/lecture.
    final wasPlaying = _player.state.playing;
    final resumeAt = _positionSeconds > 3 ? _positionSeconds.floor() - 3 : 0;
    await _persistPosition(); // filet de sécurité en base
    if (!mounted) return;
    setState(() {
      _ready = false;
      _error = null;
    });
    await _player.stop();
    await _loadAndPlay(forceResumeAt: resumeAt, startPaused: !wasPlaying);
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
  ///
  /// [forceResumeAt] (secondes) : reprend directement à cette position sans
  /// demander « Reprendre/Recommencer » — utilisé au changement de langue pour
  /// conserver le timecode (même épisode, autre piste).
  /// [startPaused] : après l'ouverture, mettre en pause (conserve l'état
  /// pause/lecture lors d'un changement de langue en pause).
  Future<void> _loadAndPlay({int? forceResumeAt, bool startPaused = false}) async {
    if (_loading) return; // garde de réentrance : évite un double « Lancer ».
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Langue : résolue une fois (préférence par anime → globale), puis pilotée
      // par le sélecteur.
      _language ??= await _preferredLanguage();
      _singleLanguage = (await ref
              .read(settingsRepositoryProvider)
              .get(SettingsKeys.singleLanguage, defaultValue: '0')) ==
          '1';
      final resolveTitle = widget.animeSamaTitle ?? widget.media.title.preferred;

      final seasonIndex = await _storedSeasonIndex();
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

      final resolver = await ref.read(activeResolverProvider.future);
      // Tente la langue courante ; si l'épisode n'existe pas dans cette langue
      // (pas encore doublé…), fallback automatique sur l'autre langue.
      String url;
      try {
        url = await resolver.resolveStreamUrl(
          title: resolveTitle,
          episode: _currentEpisode,
          season: seasonIndex,
          language: _language!,
        );
      } on ResolveException {
        final other = _language == PlaybackLanguage.vf
            ? PlaybackLanguage.vostfr
            : PlaybackLanguage.vf;
        url = await resolver.resolveStreamUrl(
          title: resolveTitle,
          episode: _currentEpisode,
          season: seasonIndex,
          language: other,
        );
        // Fallback réussi → on bascule sur la langue qui marche + on prévient.
        _language = other;
        if (mounted) {
          final label = other == PlaybackLanguage.vf ? 'VF' : 'VOSTFR';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Langue indisponible pour cet épisode — lecture en $label')),
          );
        }
      }

      // Mémorise la langue effective pour cet anime + lance la détection des
      // langues dispo (pour le sélecteur), sauf en mode « langue unique ».
      await _persistLanguage(_language!);
      if (!_singleLanguage) {
        _refreshAvailableLangs(resolveTitle, seasonIndex, _currentEpisode);
      }

      // Reprise : au changement de langue on reprend DIRECTEMENT au timecode
      // fourni (même épisode). Sinon, si une position a été enregistrée pour
      // cet épisode (non vu), proposer « Reprendre » / « Recommencer ».
      final int? resumeFrom =
          forceResumeAt ?? await _resumePositionSeconds();

      // On passe la position de départ à l'OUVERTURE (Media.start) : mpv décode
      // l'image au bon endroit dès le chargement, ce qui évite l'image noire
      // d'un seek effectué après coup sur un flux HLS.
      final startAt = (resumeFrom != null && resumeFrom > 0)
          ? Duration(seconds: resumeFrom)
          : null;
      await _player.open(Media(url, start: startAt), play: true);

      // Applique les propriétés mpv (seek exact, buffers…) MAINTENANT que le
      // backend est actif : posées avant l'open, elles étaient ignorées.
      await _applyMpvProperties();

      // Lancer la lecture = « je regarde cet anime » → le passer EN COURS
      // (et l'ajouter à la bibliothèque s'il n'y était pas). Best-effort.
      await _ensureWatchingStatus();

      // Conserve l'état pause/lecture (switch de langue effectué en pause).
      if (startPaused) {
        try {
          await _player.pause();
        } catch (_) {/* ignore */}
      }

      // Réapplique la vitesse choisie (mpv la remet à 1.0 à chaque open).
      if (_speed != 1.0) {
        try {
          await _player.setRate(_speed);
        } catch (_) {/* ignore */}
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

  /// Garantit que l'anime est « En cours » dès qu'on lance la lecture (règle :
  /// regarder = suivre l'anime). Crée l'entrée en base si l'anime n'était dans
  /// aucune liste. N'écrase JAMAIS un statut « Terminé » (revoir un épisode d'un
  /// anime fini ne doit pas le rétrograder). Best-effort : n'interrompt jamais
  /// la lecture en cas d'erreur.
  Future<void> _ensureWatchingStatus() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.anilistId);
      // Déjà En cours → rien à faire. Déjà Terminé → ne pas rétrograder.
      if (existing != null &&
          (existing.status == ListStatus.current ||
              existing.status == ListStatus.completed)) {
        return;
      }
      final base = existing ??
          ListEntry(
            mediaId: widget.media.anilistId,
            status: ListStatus.current,
            updatedAt: DateTime.now(),
          );
      final updated =
          base.copyWith(status: ListStatus.current, updatedAt: DateTime.now());
      await listRepo.upsertEntry(updated);
      _currentEntry = updated;
      // Rafraîchit bibliothèque + fiche pour refléter le nouveau statut.
      ref.invalidate(entriesByStatusProvider);
      ref.invalidate(countByStatusProvider);
      ref.invalidate(listEntryProvider(widget.media.anilistId));
    } catch (_) {/* best-effort : ne bloque pas la lecture */}
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
    if (pos < 15) return null; // trop peu → démarrage normal
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


  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Persiste la position dès qu'au moins ~5 s se sont écoulées depuis la
  /// dernière écriture. On ne se cale PAS sur les multiples exacts de 5 (le
  /// stream position émet a un rythme irrégulier et pourrait les sauter →
  /// aucune écriture, donc pas de reprise possible).
  void _maybePersistPosition() {
    final whole = _positionSeconds.floor();
    if (_lastPersistedWhole >= 0 && (whole - _lastPersistedWhole).abs() < 5) {
      return;
    }
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

  /// Fin d'épisode atteinte : marque vu, remet la position à 0, tente de passer
  /// la série en « Terminé » si toutes les saisons sont vues, et lance
  /// l'auto-play si activé dans les réglages et qu'un épisode suivant existe.
  Future<void> _onEpisodeCompleted() async {
    await _markCurrentWatched();
    _positionSeconds = 0;
    _lastPersistedWhole = -1;

    // Toutes les saisons entièrement vues → l'anime passe « Terminé » tout seul.
    await _maybeMarkSeriesCompleted();

    final autoPlay = await _autoPlayEnabled();
    final next = _nextEpisode;
    if (!autoPlay || next == null) {
      if (mounted) setState(() {});
      return;
    }
    _startAutoPlayCountdown(next);
  }

  /// Passe l'anime en « Terminé » si TOUTES les saisons anime-sama ont leur
  /// dernier épisode vu (vérification complète, pas seulement la saison
  /// courante). S'appuie sur les données anime-sama (fiables) plutôt que sur
  /// `media.episodes` (Jikan), null pour les longues séries comme One Piece.
  /// Remplit aussi `entry.progress` avec le total réel d'épisodes. Best-effort.
  Future<void> _maybeMarkSeriesCompleted() async {
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.anilistId);
      if (existing != null && existing.status == ListStatus.completed) return;

      final title = widget.animeSamaTitle ?? widget.media.title.preferred;
      final seasons = await ref.read(animeSamaSeasonsProvider(title).future);
      if (seasons.isEmpty) return;

      final seasonProgress = ref.read(seasonProgressRepositoryProvider);
      var totalEpisodes = 0;
      for (final s in seasons) {
        final eps = await ref.read(animeSamaEpisodesProvider(
          (title: title, seasonIndex: s.index),
        ).future);
        if (eps.isEmpty) return; // saison sans épisodes listés → on n'affirme rien.
        totalEpisodes += eps.length;
        final watched =
            await seasonProgress.lastWatched(widget.media.anilistId, s.index);
        final done = watched >= SeasonProgressRepository.fullyWatchedSentinel ||
            watched >= eps.last;
        if (!done) return; // au moins une saison non finie → pas « Terminé ».
      }

      // Toutes les saisons sont vues → Terminé + progress = total réel.
      final base = existing ??
          ListEntry(
            mediaId: widget.media.anilistId,
            status: ListStatus.completed,
            updatedAt: DateTime.now(),
          );
      final newProgress =
          totalEpisodes > base.progress ? totalEpisodes : base.progress;
      await listRepo.upsertEntry(base.copyWith(
        status: ListStatus.completed,
        progress: newProgress,
        updatedAt: DateTime.now(),
      ));
      ref.invalidate(entriesByStatusProvider);
      ref.invalidate(countByStatusProvider);
      ref.invalidate(listEntryProvider(widget.media.anilistId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anime terminé ! 🎉')),
        );
      }
    } catch (_) {/* best-effort : ne bloque pas la lecture */}
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
  /// reculer RÉTROGRADE la progression à l'épisode précédent choisi (règle
  /// utilisateur : reculer = revenir en arrière dans sa progression). Ne lance
  /// PAS la lecture : le bouton « Lancer » réapparaît pour le nouvel épisode.
  Future<void> _goToEpisode(int ep) async {
    if (ep == _currentEpisode) return;
    if (_navigating) return; // garde : évite un double marquage si clics rapides.
    _navigating = true;
    _autoPlayTimer?.cancel();
    _autoPlayCountdown = null;
    // Annule un saut ←/→ en attente (il viserait le mauvais épisode).
    _seekDebounce?.cancel();
    _seekTarget = null;
    try {
      if (ep > _currentEpisode) {
        await _markCurrentWatched();
      } else {
        // Recul : sauvegarde la position de l'épisode qu'on quitte, puis
        // rétrograde la progression à (ep - 1) : on n'a plus « vu » les épisodes
        // >= ep. Ex : à l'ép 10, on revient à l'ép 5 → progression = 4 vus.
        await _persistPosition();
        await _rewindProgressTo(ep);
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

  /// Rétrograde la progression à « [ep] - 1 vus » : on considère les épisodes à
  /// partir de [ep] comme non vus. Met à jour la progression PAR SAISON et
  /// l'entrée de liste (statut repassé « En cours » si c'était « Terminé »).
  Future<void> _rewindProgressTo(int ep) async {
    final target = ep - 1 < 0 ? 0 : ep - 1;
    // Progression par saison : abaisse le compteur (setLastWatched borne à >=0
    // et écrit la valeur telle quelle, même plus basse que l'actuelle).
    await ref
        .read(seasonProgressRepositoryProvider)
        .setLastWatched(widget.media.anilistId, _seasonIndex, target);

    // Entrée de liste : rétrograde progress + repasse « En cours » si l'anime
    // était marqué « Terminé » (on n'a plus tout vu).
    try {
      final listRepo = ref.read(listRepositoryProvider);
      final existing = await listRepo.getEntry(widget.media.anilistId);
      if (existing != null) {
        final newProgress =
            existing.progress > target ? target : existing.progress;
        final newStatus = existing.status == ListStatus.completed
            ? ListStatus.current
            : existing.status;
        if (newProgress != existing.progress ||
            newStatus != existing.status) {
          await listRepo.upsertEntry(existing.copyWith(
            progress: newProgress,
            status: newStatus,
            updatedAt: DateTime.now(),
          ));
          _currentEntry = existing.copyWith(
            progress: newProgress,
            status: newStatus,
            updatedAt: DateTime.now(),
          );
          ref.invalidate(entriesByStatusProvider);
          ref.invalidate(countByStatusProvider);
          ref.invalidate(listEntryProvider(widget.media.anilistId));
        }
      }
    } catch (_) {/* best-effort */}
  }

  /// Valide la fin de saison : marque le dernier épisode vu (compteur = total).
  /// Si c'était la dernière saison non finie, l'anime passe « Terminé » tout
  /// seul (cf. _maybeMarkSeriesCompleted).
  Future<void> _finishSeason() async {
    await _markCurrentWatched();
    await _maybeMarkSeriesCompleted();
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

  /// Change la vitesse de lecture (best-effort).
  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    try {
      await _player.setRate(speed);
    } catch (_) {/* ignore */}
  }

  /// Vidéo + contrôles media_kit personnalisés : un bouton « réglages » est
  /// ajouté à la barre haute du player (présente aussi EN PLEIN ÉCRAN). Il
  /// ouvre le menu langue + vitesse. On utilise MaterialDesktopCustomButton
  /// (les PopupMenuButton bruts ne reçoivent pas les taps dans cette barre).
  Widget _buildVideo() {
    // Barre haute : un bouton « réglages ». On construit une instance DISTINCTE
    // (clé distincte) pour la barre normale et pour la barre plein écran, car
    // media_kit monte les deux en même temps — partager le widget/la clé lève
    // « Multiple widgets used the same GlobalKey ».
    List<Widget> topBar(GlobalKey key) => <Widget>[
          const Spacer(),
          MaterialDesktopCustomButton(
            key: key,
            icon: const Icon(Icons.tune),
            onPressed: () => _showSettingsMenuFromButton(key),
          ),
        ];

    // Raccourcis clavier : reprend les défauts media_kit mais avec les durées
    // de saut avant/arrière configurées dans les Paramètres.
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space): _player.playOrPause,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekBy(-_seekBackward),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekBy(_seekForward),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        final v = _player.state.volume + 5.0;
        _player.setVolume(v.clamp(0.0, 100.0));
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        final v = _player.state.volume - 5.0;
        _player.setVolume(v.clamp(0.0, 100.0));
      },
    };

    // Desktop (Windows) : les contrôles sont MaterialDesktop*, pas Material*.
    // Utiliser la mauvaise variante rend les boutons custom invisibles.
    return MaterialDesktopVideoControlsTheme(
      normal: MaterialDesktopVideoControlsThemeData(
        topButtonBar: topBar(_settingsButtonKey),
        keyboardShortcuts: shortcuts,
      ),
      fullscreen: MaterialDesktopVideoControlsThemeData(
        topButtonBar: topBar(_settingsButtonKeyFs),
        keyboardShortcuts: shortcuts,
      ),
      child: Video(controller: _videoController),
    );
  }

  /// Saut relatif (secondes). Les appuis rapides s'accumulent sur une cible
  /// commune (partant de la position courante réelle) et un seul seek est
  /// appliqué après une courte pause — évite d'empiler des seeks sur une
  /// position pas encore stabilisée (boucle/désync, surtout en recul).
  void _seekBy(int seconds) {
    // Base = cible en cours d'accumulation, sinon position réelle du lecteur.
    final base = _seekTarget ?? _player.state.position;
    var target = base + Duration(seconds: seconds);
    final dur = _player.state.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    _seekTarget = target;

    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 150), () {
      final t = _seekTarget;
      _seekTarget = null;
      if (t != null) _player.seek(t);
    });
  }

  /// Ouvre le menu réglages ancré sous le bouton « tune » de la barre du player.
  /// [key] désigne le bouton effectivement monté (barre normale ou plein écran).
  Future<void> _showSettingsMenuFromButton(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    // Ancre le menu juste sous le bouton.
    final pos = box.localToGlobal(box.size.bottomLeft(Offset.zero));
    await _showContextMenu(pos);
  }

  /// Menu contextuel (clic droit) : langue + vitesse. Indispensable en plein
  /// écran où la barre au-dessus du lecteur est masquée.
  Future<void> _showContextMenu(Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    // Entrées langue (si dispo et pas en mode langue unique).
    final langItems = <PopupMenuEntry<Object>>[];
    if (!_singleLanguage) {
      for (final entry in const [
        (PlaybackLanguage.vostfr, 'VOSTFR'),
        (PlaybackLanguage.vf, 'VF'),
      ]) {
        final lang = entry.$1;
        final enabled = _availableLangs == null || _availableLangs!.contains(lang);
        langItems.add(PopupMenuItem<Object>(
          value: lang,
          enabled: enabled,
          child: Row(
            children: [
              Icon(_language == lang ? Icons.check : Icons.subtitles_outlined,
                  size: 18),
              const SizedBox(width: 8),
              Text(entry.$2),
            ],
          ),
        ));
      }
      langItems.add(const PopupMenuDivider());
    }

    final selected = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        ...langItems,
        for (final s in _speeds)
          PopupMenuItem<Object>(
            value: s,
            child: Row(
              children: [
                Icon(_speed == s ? Icons.check : Icons.speed, size: 18),
                const SizedBox(width: 8),
                Text(s == 1.0 ? 'Vitesse : Normal (1×)' : 'Vitesse : $s×'),
              ],
            ),
          ),
      ],
    );

    if (selected is PlaybackLanguage) {
      await _switchLanguage(selected);
    } else if (selected is double) {
      await _setSpeed(selected);
    }
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
                // --- Sélecteur de langue, au-dessus du lecteur (mode fenêtré) ---
                if (!_singleLanguage) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _LanguageSelector(
                      current: _language,
                      available: _availableLangs,
                      onChanged: _switchLanguage,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // --- Lecteur encastré media_kit ---
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      // Clic droit → menu contextuel (langue + vitesse), utile
                      // en plein écran où la barre du dessus est masquée.
                      onSecondaryTapDown: (d) =>
                          _showContextMenu(d.globalPosition),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.black),
                          if (_ready)
                            _buildVideo()
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
// Sélecteur de langue VF/VOSTFR (au-dessus du lecteur)
// ---------------------------------------------------------------------------

class _LanguageSelector extends StatelessWidget {
  final PlaybackLanguage? current;

  /// Langues disponibles pour l'épisode courant. `null` = pas encore testé
  /// (on ne grise rien, les deux restent cliquables).
  final Set<PlaybackLanguage>? available;
  final ValueChanged<PlaybackLanguage> onChanged;

  const _LanguageSelector({
    required this.current,
    required this.available,
    required this.onChanged,
  });

  bool _enabled(PlaybackLanguage lang) =>
      available == null || available!.contains(lang);

  @override
  Widget build(BuildContext context) {
    Widget chip(PlaybackLanguage lang, String label) {
      final enabled = _enabled(lang);
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: current == lang,
          visualDensity: VisualDensity.compact,
          // Grisé si la langue n'existe pas pour cet épisode.
          onSelected: enabled ? (_) => onChanged(lang) : null,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(PlaybackLanguage.vostfr, 'VOSTFR'),
        chip(PlaybackLanguage.vf, 'VF'),
      ],
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
