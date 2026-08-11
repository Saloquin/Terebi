/// Écran de démarrage animé : joue `loading.mp4` via media_kit, puis appelle
/// [onDone]. Un timeout de secours garantit qu'on ne reste jamais bloqué si la
/// vidéo n'émet pas d'événement « terminé ».
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

class SplashScreen extends StatefulWidget {
  /// Appelé quand la vidéo est terminée (ou au timeout de secours).
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  StreamSubscription<bool>? _completedSub;
  Timer? _fallbackTimer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Timeout de secours : ne jamais rester bloqué sur le splash.
    _fallbackTimer = Timer(const Duration(seconds: 8), _finish);
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) _finish();
    });
    _start();
  }

  Future<void> _start() async {
    try {
      // media_kit lit un fichier local : on extrait l'asset sur disque.
      final path = await _extractLoadingVideo();
      await _player.open(Media(path));
    } catch (_) {
      _finish(); // en cas d'échec, on passe directement à l'app
    }
  }

  /// Extrait `assets/branding/loading.mp4` vers un fichier temporaire (réécrit
  /// seulement si absent ou taille différente).
  Future<String> _extractLoadingVideo() async {
    final bytes = await rootBundle.load('assets/branding/loading.mp4');
    final dir = await getTemporaryDirectory();
    final dest = File('${dir.path}${Platform.pathSeparator}terebi_loading.mp4');
    final data = bytes.buffer.asUint8List();
    if (!dest.existsSync() || await dest.length() != data.length) {
      await dest.writeAsBytes(data, flush: true);
    }
    return dest.path;
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _fallbackTimer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _completedSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(controller: _controller, controls: NoVideoControls),
        ),
      ),
    );
  }
}
