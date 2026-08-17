/// Tests du HealthService — dart:test, sondes injectées.
/// Le check Python a été retiré : le résolveur est 100% Dart depuis la phase 7.
library;

import 'package:test/test.dart';
import 'package:terebi/src/services/health_service.dart';

void main() {
  HealthService service({
    bool db = true,
    bool net = true,
    bool? aniSkip,
  }) =>
      HealthService(
        databaseOk: () async => db,
        networkOk: () async => net,
        aniSkipOk: aniSkip == null ? null : () async => aniSkip,
      );

  test('tout OK → allOk, aucun problème', () async {
    final report = await service().run();

    expect(report.allOk, isTrue);
    expect(report.problems, isEmpty);
  });

  test('DB KO remonte dans problems', () async {
    final report = await service(db: false).run();
    expect(report.allOk, isFalse);
    final check =
        report.checks.firstWhere((c) => c.component == 'base de donnees');
    expect(check.state, HealthState.error);
  });

  test('réseau KO remonte dans problems', () async {
    final report = await service(net: false).run();
    final check =
        report.checks.firstWhere((c) => c.component == 'anime-sama');
    expect(check.state, HealthState.error);
  });

  test('DB et réseau KO remontent dans problems', () async {
    final report = await service(db: false, net: false).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps, containsAll(['base de donnees', 'anime-sama']));
  });

  test('sonde aniskip absente par défaut (non listée)', () async {
    final report = await service().run();
    final comps = report.checks.map((c) => c.component).toSet();
    expect(comps.contains('aniskip'), isFalse);
    // Python n'est plus dans les checks.
    expect(comps.contains('python'), isFalse);
  });

  test('aniskip KO remonte dans problems quand la sonde est fournie', () async {
    final report = await service(aniSkip: false).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps, contains('aniskip'));
  });

  test('aniskip OK ne remonte pas dans problems', () async {
    final report = await service(aniSkip: true).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps.contains('aniskip'), isFalse);
  });
}
