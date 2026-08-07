/// Couche infrastructure — autorisé à importer Flutter (path_provider,
/// flutter/services). Non testable via `dart test` (dépend de rootBundle).
///
/// Extrait le wrapper Python `animesama_resolve.py` depuis les assets Flutter
/// vers un répertoire sur disque accessible par Python.
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Retourne le chemin sur disque du wrapper `animesama_resolve.py`.
///
/// L'asset `assets/resolver/animesama_resolve.py` est copié dans
/// `getApplicationSupportDirectory()/animesama_resolve.py` si le fichier
/// n'existe pas encore ou si le contenu diffère (mise à jour de l'app).
///
/// Lève une exception si la lecture de l'asset ou l'écriture échoue.
Future<String> ensureWrapperScript() async {
  const assetKey = 'assets/resolver/animesama_resolve.py';
  const fileName = 'animesama_resolve.py';

  final assetContent = await rootBundle.loadString(assetKey);
  final supportDir = await getApplicationSupportDirectory();
  final dest = File('${supportDir.path}${Platform.pathSeparator}$fileName');

  // Écrit seulement si absent ou contenu différent (évite I/O inutile).
  if (!dest.existsSync() || await dest.readAsString() != assetContent) {
    await dest.writeAsString(assetContent, flush: true);
  }

  return dest.path;
}
