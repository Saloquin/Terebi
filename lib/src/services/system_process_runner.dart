/// Implémentation réelle de [ProcessRunner] basée sur `dart:io`.
///
/// Ce fichier est le SEUL de la couche services à importer dart:io —
/// il est exclu de la suite de tests (dépend de vrais binaires).
library;

// ignore: depend_on_referenced_packages
import 'dart:io' as io;

import 'process_runner.dart';

/// Lance [executable] avec [args] via [io.Process.run] et retourne un
/// [ProcessResult] avec stdout/stderr/exitCode.
///
/// Les exceptions de lancement (binaire introuvable, permission refusée…)
/// remontent telles quelles ; [HealthService] les intercepte et les classe
/// comme `missing`.
Future<ProcessResult> systemProcessRunner(
  String executable,
  List<String> args, {
  Map<String, String>? environment,
}) async {
  final env = <String, String>{...?environment};

  // Si on lance un shell POSIX (Git Bash), s'assurer que ses outils Unix
  // (cut, sed, grep, head, curl…) situés dans le même dossier sont dans le PATH.
  // Sinon ani-cli échoue avec « cut: command not found ».
  if (io.Platform.isWindows &&
      RegExp(r'(sh|bash)\.exe$', caseSensitive: false).hasMatch(executable)) {
    final toolsDir = io.File(executable).parent.path; // …\Git\usr\bin
    final parentPath = io.Platform.environment['PATH'] ??
        io.Platform.environment['Path'] ??
        '';
    env['PATH'] = parentPath.isEmpty ? toolsDir : '$toolsDir;$parentPath';
  }

  final result = await io.Process.run(
    executable,
    args,
    environment: env.isEmpty ? null : env,
    includeParentEnvironment: true,
  );
  return ProcessResult(
    exitCode: result.exitCode,
    stdout: result.stdout as String? ?? '',
    stderr: result.stderr as String? ?? '',
  );
}

/// Valeurs par défaut pour AnimeSamaResolver : Python + chemin anime_sama.py.
///
/// Détection automatique au démarrage ; si un chemin est introuvable il reste
/// vide (`''`) et l'utilisateur devra le renseigner dans les Paramètres.
class AnimeSamaDefaults {
  /// Exécutable Python (`python` sous Windows, `python3` sinon, ou path absolu).
  final String pythonPath;

  /// Chemin du script `anime_sama.py` du projet animesama-cli installé.
  /// Vide (`''`) si introuvable — à renseigner dans les Paramètres.
  final String animeSamaScriptPath;

  const AnimeSamaDefaults({
    required this.pythonPath,
    required this.animeSamaScriptPath,
  });

  /// Détecte Python et anime_sama.py sur la machine courante.
  ///
  /// **Python** : sous Windows on préfère `python` (Microsoft Store / officiel) ;
  /// sous Linux/macOS on préfère `python3`.
  ///
  /// **anime_sama.py** : cherche dans les emplacements plausibles d'une install
  /// pipx ou scoop d'animesama-cli. Si introuvable, renvoie `''`.
  static AnimeSamaDefaults detect() {
    final python = io.Platform.isWindows ? 'python' : 'python3';

    final home = io.Platform.environment['USERPROFILE'] ??
        io.Platform.environment['HOME'] ??
        '';
    final scoop = io.Platform.environment['SCOOP'] ??
        (home.isNotEmpty ? '$home\\scoop' : '');
    final localAppData = io.Platform.environment['LOCALAPPDATA'] ?? '';

    // Emplacements plausibles d'anime_sama.py (pipx, scoop, install manuelle).
    final candidates = <String>[
      // pipx sous Windows (%LOCALAPPDATA%\pipx\venvs\animesama-cli\...)
      if (localAppData.isNotEmpty)
        '$localAppData\\pipx\\venvs\\animesama-cli\\Lib\\site-packages\\anime_sama.py',
      // pipx sous Linux/macOS (~/.local/pipx/venvs/...)
      if (home.isNotEmpty)
        '$home/.local/pipx/venvs/animesama-cli/lib/python3.12/site-packages/anime_sama.py',
      if (home.isNotEmpty)
        '$home/.local/pipx/venvs/animesama-cli/lib/python3.11/site-packages/anime_sama.py',
      if (home.isNotEmpty)
        '$home/.local/pipx/venvs/animesama-cli/lib/python3.10/site-packages/anime_sama.py',
      // scoop sous Windows
      if (scoop.isNotEmpty)
        '$scoop\\apps\\animesama-cli\\current\\anime_sama.py',
      // install manuelle dans ~/bin ou ~/.local/bin
      if (home.isNotEmpty) '$home\\bin\\anime_sama.py',
      if (home.isNotEmpty) '$home/.local/bin/anime_sama.py',
      // site-packages standard (pip install --user)
      if (home.isNotEmpty)
        '$home/AppData/Roaming/Python/Python312/site-packages/anime_sama.py',
      if (home.isNotEmpty)
        '$home/AppData/Roaming/Python/Python311/site-packages/anime_sama.py',
    ];

    final scriptPath = candidates.firstWhere(
      (p) => io.File(p).existsSync(),
      orElse: () => '',
    );

    return AnimeSamaDefaults(
      pythonPath: python,
      animeSamaScriptPath: scriptPath,
    );
  }
}
