import 'package:test/test.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/services/health_service.dart';

void main() {
  // Runner qui simule des binaires présents/absents selon un dictionnaire.
  ProcessRunner runnerWith(Map<String, ProcessResult> present) =>
      (exe, args, {Map<String, String>? environment}) async {
        final r = present[exe];
        if (r == null) throw Exception('binaire introuvable: $exe');
        return r;
      };

  HealthService service({
    Map<String, ProcessResult> binaries = const {},
    bool db = true,
    bool net = true,
  }) =>
      HealthService(
        runner: runnerWith(binaries),
        databaseOk: () async => db,
        networkOk: () async => net,
      );

  test('tout OK → allOk, aucun problème', () async {
    final report = await service(
      binaries: {
        'mpv': const ProcessResult(exitCode: 0, stdout: 'mpv 0.38'),
      },
    ).run();

    expect(report.allOk, isTrue);
    expect(report.problems, isEmpty);
    final mpv = report.checks.firstWhere((c) => c.component == 'mpv');
    expect(mpv.detail, 'mpv 0.38');
  });

  test('mpv absent → missing', () async {
    final report = await service(binaries: const {}).run();
    expect(report.allOk, isFalse);
    final mpv = report.checks.firstWhere((c) => c.component == 'mpv');
    expect(mpv.state, HealthState.missing);
    expect(mpv.detail, contains('Installation requise'));
  });

  test('binaire présent mais code non nul → error', () async {
    final report = await service(
      binaries: {
        'mpv': const ProcessResult(exitCode: 2, stderr: 'bad'),
      },
    ).run();
    final mpv = report.checks.firstWhere((c) => c.component == 'mpv');
    expect(mpv.state, HealthState.error);
  });

  test('DB et réseau KO remontent dans problems', () async {
    final report = await service(
      binaries: {
        'mpv': const ProcessResult(exitCode: 0),
      },
      db: false,
      net: false,
    ).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps, containsAll(['database', 'network']));
  });
}
