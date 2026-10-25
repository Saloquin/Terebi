library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppPlatform {
  /// Android TV / Fire TV — navigation D-pad, interface dédiée grand écran.
  tv,
  /// Android téléphone / tablette — interface mobile tactile.
  mobile,
  /// Windows / Linux / macOS — NavigationRail, interface bureau.
  desktop,
}

/// Mode d'affichage forcé ou automatique.
enum LayoutMode {
  /// Automatique : selon la plateforme et la taille d'écran.
  auto,
  /// Forcer l'interface bureau.
  desktop,
  /// Forcer l'interface mobile smartphone.
  mobile,
  /// Forcer l'interface Android TV (D-Pad télécommande).
  tv,
}

/// Provider pour forcer ou laisser automatique le choix de l'interface bureau / mobile / TV.
final layoutModeProvider = StateProvider<LayoutMode>((ref) => LayoutMode.auto);

/// Plateforme détectée au démarrage. Surchargée dans main.dart après détection Android TV.
final appPlatformProvider = StateProvider<AppPlatform>((ref) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AppPlatform.mobile;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return AppPlatform.desktop;
    default:
      return AppPlatform.desktop;
  }
});
