/// Couche infrastructure — autorisé à importer Flutter (path_provider,
/// flutter/services). Non testable via `dart test` (dépend de rootBundle).
///
/// Extrait les scripts Python du résolveur depuis les assets Flutter vers un
/// répertoire sur disque accessible par Python :
/// - `animesama_resolve.py` : le wrapper maison ;
/// - `anime_sama.py` : le script tiers animesama-cli (embarqué pour éviter une
///   installation manuelle ; ne dépend que de `requests` + `beautifulsoup4`).
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Extrait un asset Python vers `getApplicationSupportDirectory()/<fileName>`.
/// N'écrit que si le fichier est absent ou si son contenu diffère (mise à jour
/// de l'app). Retourne le chemin sur disque.
Future<String> _extractAsset(String assetKey, String fileName) async {
  final assetContent = await rootBundle.loadString(assetKey);
  final supportDir = await getApplicationSupportDirectory();
  final dest = File('${supportDir.path}${Platform.pathSeparator}$fileName');
  if (!dest.existsSync() || await dest.readAsString() != assetContent) {
    await dest.writeAsString(assetContent, flush: true);
  }
  return dest.path;
}

/// Chemin sur disque du wrapper `animesama_resolve.py` (extrait des assets).
Future<String> ensureWrapperScript() =>
    _extractAsset('assets/resolver/animesama_resolve.py', 'animesama_resolve.py');

/// Chemin sur disque du script tiers `anime_sama.py` (extrait des assets).
/// Évite d'avoir à l'installer et à saisir son chemin manuellement.
Future<String> ensureAnimeSamaScript() =>
    _extractAsset('assets/resolver/anime_sama.py', 'anime_sama.py');
