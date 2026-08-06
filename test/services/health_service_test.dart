import 'package:test/test.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/services/health_service.dart';

void main() {
  // Runner qui simule des binaires présents/absents selon un dictionnaire.
  ProcessRunner runnerWith(Map<String, ProcessResult> present) =>
      (exe, args) async {
        final r = present[exe];
        if (r == null) throw Exception('binaire introuvable: $exe');
        return r;
      };

  HealthService service({
    Map<String, ProcessResult> binaries = const {},
    bool token = true,
    bool db = true,
    bool net = true,
  }) =>
      HealthService(
        runner: runnerWith(binaries),
        hasValidToken: () async => token,
        databaseOk: () async => db,
        networkOk: () async => net,
      );

  test('tout OK → allOk, aucun problème', () async {
    final report = await service(
      binaries: {
        'ani-cli': const ProcessResult(exitCode: 0, stdout: 'ani-cli 4.8'),
        'mpv': const ProcessResult(exitCode: 0, stdout: 'mpv 0.38'),
      },
    ).run();

    expect(report.allOk, isTrue);
    expect(report.problems, isEmpty);
    final aniCli = report.checks.firstWhere((c) => c.component == 'ani-cli');
    expect(aniCli.detail, 'ani-cli 4.8');
  });

  test('ani-cli et mpv absents → missing', () async {
    final report = await service(binaries: const {}).run();
    expect(report.allOk, isFalse);
    final aniCli = report.checks.firstWhere((c) => c.component == 'ani-cli');
    final mpv = report.checks.firstWhere((c) => c.component == 'mpv');
    expect(aniCli.state, HealthState.missing);
    expect(mpv.state, HealthState.missing);
    expect(aniCli.detail, contains('Installation requise'));
  });

  test('token invalide → problème signalé', () async {
    final report = await service(
      binaries: {
        'ani-cli': const ProcessResult(exitCode: 0),
        'mpv': const ProcessResult(exitCode: 0),
      },
      token: false,
    ).run();
    expect(report.allOk, isFalse);
    final t = report.checks.firstWhere((c) => c.component == 'anilist-token');
    expect(t.state, HealthState.error);
  });

  test('binaire présent mais code non nul → error', () async {
    final report = await service(
      binaries: {
        'ani-cli': const ProcessResult(exitCode: 2, stderr: 'bad'),
        'mpv': const ProcessResult(exitCode: 0),
      },
    ).run();
    final aniCli = report.checks.firstWhere((c) => c.component == 'ani-cli');
    expect(aniCli.state, HealthState.error);
  });

  test('DB et réseau KO remontent dans problems', () async {
    final report = await service(
      binaries: {
        'ani-cli': const ProcessResult(exitCode: 0),
        'mpv': const ProcessResult(exitCode: 0),
      },
      db: false,
      net: false,
    ).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps, containsAll(['database', 'network']));
  });
}
