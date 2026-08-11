/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Health-check des dépendances externes : mpv, base de données, réseau.
/// Chaque sonde est injectable pour être testable.
library;

import 'process_runner.dart';

/// État d'un composant vérifié.
enum HealthState { ok, missing, error }

/// Résultat d'une sonde de santé.
class HealthCheck {
  /// Identifiant du composant (ex. `ani-cli`, `mpv`, `anilist-token`).
  final String component;
  final HealthState state;

  /// Détail lisible (version détectée, message d'erreur, conseil d'installation).
  final String? detail;

  const HealthCheck({
    required this.component,
    required this.state,
    this.detail,
  });

  bool get isOk => state == HealthState.ok;
}

/// Rapport global de santé.
class HealthReport {
  final List<HealthCheck> checks;
  const HealthReport(this.checks);

  /// `true` si tous les composants **requis** sont OK.
  bool get allOk => checks.every((c) => c.isOk);

  /// Composants non OK (à corriger / installer).
  List<HealthCheck> get problems =>
      checks.where((c) => !c.isOk).toList(growable: false);
}

/// Effectue les sondes de santé. Toutes les dépendances externes sont injectées.
class HealthService {
  final ProcessRunner runner;
  final String mpvPath;

  /// Renvoie `true` si la base de données est ouvrable (injecté).
  final Future<bool> Function() databaseOk;

  /// Renvoie `true` si le réseau/AniList est joignable (injecté).
  final Future<bool> Function() networkOk;

  const HealthService({
    required this.runner,
    this.mpvPath = 'mpv',
    required this.databaseOk,
    required this.networkOk,
  });

  /// Vérifie qu'un exécutable répond à `--version`. [prefixArgs] est inséré
  /// avant `--version` (ex. le chemin du script quand on passe par un shell).
  /// `missing` si introuvable (exception), `error` si code non nul.
  Future<HealthCheck> _checkBinary(
    String component,
    String path, {
    List<String> prefixArgs = const [],
  }) async {
    try {
      final r = await runner(path, [...prefixArgs, '--version']);
      if (r.ok) {
        final version = r.stdout.trim().split('\n').first;
        return HealthCheck(
          component: component,
          state: HealthState.ok,
          detail: version.isEmpty ? null : version,
        );
      }
      return HealthCheck(
        component: component,
        state: HealthState.error,
        detail: 'Code ${r.exitCode}',
      );
    } catch (e) {
      return HealthCheck(
        component: component,
        state: HealthState.missing,
        detail: '$component introuvable ($path). Installation requise.',
      );
    }
  }

  Future<HealthCheck> _checkBool(
    String component,
    Future<bool> Function() probe,
    String failDetail,
  ) async {
    try {
      final ok = await probe();
      return HealthCheck(
        component: component,
        state: ok ? HealthState.ok : HealthState.error,
        detail: ok ? null : failDetail,
      );
    } catch (e) {
      return HealthCheck(
        component: component,
        state: HealthState.error,
        detail: '$failDetail ($e)',
      );
    }
  }

  /// Lance toutes les sondes et agrège le rapport.
  Future<HealthReport> run() async {
    final checks = await Future.wait([
      _checkBinary('mpv', mpvPath),
      _checkBool('database', databaseOk, 'Base de données inaccessible.'),
      _checkBool('network', networkOk, 'AniList/réseau injoignable.'),
    ]);
    return HealthReport(checks);
  }
}
