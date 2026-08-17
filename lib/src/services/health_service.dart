/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Health-check des dépendances externes : base de données, réseau, AniSkip.
/// Le check Python a été retiré : le résolveur est 100% Dart depuis la phase 7.
/// Chaque sonde est injectable pour être testable.
library;

/// État d'un composant vérifié.
enum HealthState { ok, missing, error }

/// Résultat d'une sonde de santé.
class HealthCheck {
  /// Identifiant du composant (ex. `base de donnees`, `anime-sama`, `aniskip`).
  final String component;
  final HealthState state;

  /// Détail lisible (message d'erreur, conseil, etc.).
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
  /// Renvoie `true` si la base de données est ouvrable (injecté).
  final Future<bool> Function() databaseOk;

  /// Renvoie `true` si anime-sama (source de contenu) est joignable (injecté).
  final Future<bool> Function() networkOk;

  /// Renvoie `true` si AniSkip (timestamps intro/outro) répond (injecté).
  /// Optionnel : AniSkip n'est pas indispensable au fonctionnement.
  final Future<bool> Function()? aniSkipOk;

  const HealthService({
    required this.databaseOk,
    required this.networkOk,
    this.aniSkipOk,
  });

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
      _checkBool('base de donnees', databaseOk, 'Base de données inaccessible.'),
      _checkBool('anime-sama', networkOk, 'anime-sama injoignable (réseau ?).'),
      if (aniSkipOk != null)
        _checkBool('aniskip', aniSkipOk!,
            'AniSkip injoignable (skip intro/outro indisponible).'),
    ]);
    return HealthReport(checks);
  }
}
