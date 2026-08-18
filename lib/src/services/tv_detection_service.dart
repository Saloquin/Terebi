/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Détecte si l'app tourne sur une Android TV via MethodChannel natif.
/// Renvoie toujours `false` sur les autres plateformes (desktop, iOS).
/// Best-effort : toute erreur MethodChannel -> false (pas bloquant).
library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.terebi.terebi/platform');

/// Appel asynchrone unique au boot, injecté via [isTvProvider].
Future<bool> detectIsTelevision() async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel.invokeMethod<bool>('isTelevision') ?? false;
  } catch (_) {
    return false;
  }
}
