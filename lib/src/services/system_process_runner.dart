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
  List<String> args,
) async {
  final result = await io.Process.run(executable, args);
  return ProcessResult(
    exitCode: result.exitCode,
    stdout: result.stdout as String? ?? '',
    stderr: result.stderr as String? ?? '',
  );
}
