library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppPlatform {
  /// Android TV / Fire TV — navigation D-pad, interface Netflix-style.
  tv,
  /// Android téléphone / tablette — interface mobile (sous-projet 2).
  mobile,
  /// Windows / Linux / macOS — NavigationRail, interface actuelle.
  desktop,
}

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
