import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Media;
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/models/list_entry.dart';
import '../domain/models/media.dart';

/// Données du lecteur actif partagé entre la vue plein écran et le mini-lecteur.
class ActivePlaybackData {
  final Media media;
  final int episode;
  final ListEntry entry;
  final String? animeSamaTitle;
  final Player player;
  final VideoController controller;
  bool isMinimized;

  ActivePlaybackData({
    required this.media,
    required this.episode,
    required this.entry,
    this.animeSamaTitle,
    required this.player,
    required this.controller,
    this.isMinimized = false,
  });
}

/// Service de gestion du lecteur actif pour le mode mini-lecteur in-app.
class ActivePlaybackService extends ChangeNotifier {
  static final ActivePlaybackService instance = ActivePlaybackService._();
  ActivePlaybackService._();

  ActivePlaybackData? _current;
  ActivePlaybackData? get current => _current;

  bool get hasActivePlayback => _current != null;
  bool get isMinimized => _current != null && _current!.isMinimized;

  /// Démarre ou met à jour le lecteur actif en mode réduit.
  void minimize({
    required Media media,
    required int episode,
    required ListEntry entry,
    String? animeSamaTitle,
    required Player player,
    required VideoController controller,
  }) {
    _current = ActivePlaybackData(
      media: media,
      episode: episode,
      entry: entry,
      animeSamaTitle: animeSamaTitle,
      player: player,
      controller: controller,
      isMinimized: true,
    );
    notifyListeners();
  }

  /// Passe en mode plein écran (agrandit le mini-lecteur).
  void maximize() {
    if (_current != null) {
      _current!.isMinimized = false;
      notifyListeners();
    }
  }

  /// Réinitialise l'état sans disposer le player (quand PlayerPage reprend la main).
  void clearWithoutDispose() {
    _current = null;
    notifyListeners();
  }

  /// Arrête et libère complètement le lecteur.
  void stop() {
    if (_current != null) {
      try {
        _current!.player.stop();
        _current!.player.dispose();
      } catch (_) {}
      _current = null;
      notifyListeners();
    }
  }
}

/// Provider Riverpod du service de lecteur actif.
final activePlaybackProvider =
    ChangeNotifierProvider<ActivePlaybackService>((ref) {
  return ActivePlaybackService.instance;
});
