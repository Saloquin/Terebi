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
  final result = await io.Process.run(
    executable,
    args,
    environment: environment,
    includeParentEnvironment: true,
  );
  return ProcessResult(
    exitCode: result.exitCode,
    stdout: result.stdout as String? ?? '',
    stderr: result.stderr as String? ?? '',
  );
}

/// Valeurs par défaut plateforme pour lancer ani-cli.
///
/// Sous **Windows**, ani-cli est un script shell exécuté via `sh` (Git Bash) ;
/// le shim Scoop `ani-cli.cmd` passe par WSL (souvent absent) → à éviter.
/// Cherche `sh.exe` de Git et le script `ani-cli` aux emplacements usuels.
class AniCliDefaults {
  /// Chemin du shell `sh`, ou `null` si non requis (Linux/macOS) ou introuvable.
  final String? shell;

  /// Chemin/nom de l'exécutable ou script ani-cli.
  final String aniCliPath;

  const AniCliDefaults({this.shell, required this.aniCliPath});

  static AniCliDefaults detect() {
    if (!io.Platform.isWindows) {
      return const AniCliDefaults(aniCliPath: 'ani-cli');
    }

    // Shell : sh.exe de Git Bash.
    const shellCandidates = [
      r'C:\Program Files\Git\usr\bin\sh.exe',
      r'C:\Program Files\Git\bin\sh.exe',
      r'C:\Program Files (x86)\Git\usr\bin\sh.exe',
    ];
    final shell = shellCandidates.firstWhere(
      (p) => io.File(p).existsSync(),
      orElse: () => '',
    );

    // Script ani-cli : emplacements usuels (install manuelle ~/bin, scoop…).
    final home = io.Platform.environment['USERPROFILE'] ??
        io.Platform.environment['HOME'] ??
        '';
    final aniCliCandidates = [
      if (home.isNotEmpty) '$home\\bin\\ani-cli',
      if (home.isNotEmpty) '$home\\scoop\\apps\\ani-cli\\current\\ani-cli',
    ];
    final aniCli = aniCliCandidates.firstWhere(
      (p) => io.File(p).existsSync(),
      orElse: () => 'ani-cli',
    );

    return AniCliDefaults(
      shell: shell.isEmpty ? null : shell,
      aniCliPath: aniCli,
    );
  }
}
