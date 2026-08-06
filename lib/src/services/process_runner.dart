/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Abstraction d'exécution d'un processus externe (ani-cli, mpv, `which`…),
/// injectable pour tester la logique sans lancer de vrai binaire.
library;

/// Résultat d'un processus terminé.
class ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const ProcessResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  bool get ok => exitCode == 0;
}

/// Lance un processus et renvoie son résultat. Implémentation réelle en prod
/// (dart:io Process.run), mock en test.
///
/// [environment] fournit des variables d'environnement supplémentaires (ex.
/// `ANI_CLI_PLAYER=debug` pour capturer l'URL de flux au lieu de jouer).
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> args, {
  Map<String, String>? environment,
});
