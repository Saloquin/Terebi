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
    bool? aniSkip,
  }) =>
      HealthService(
        runner: runnerWith(binaries),
        databaseOk: () async => db,
        networkOk: () async => net,
        aniSkipOk: aniSkip == null ? null : () async => aniSkip,
      );

  test('tout OK → allOk, aucun problème', () async {
    final report = await service(
      binaries: {
        'python': const ProcessResult(exitCode: 0, stdout: 'Python 3.12'),
      },
    ).run();

    expect(report.allOk, isTrue);
    expect(report.problems, isEmpty);
    final python = report.checks.firstWhere((c) => c.component == 'python');
    expect(python.detail, 'Python 3.12');
  });

  test('python absent → missing', () async {
    final report = await service(binaries: const {}).run();
    expect(report.allOk, isFalse);
    final python = report.checks.firstWhere((c) => c.component == 'python');
    expect(python.state, HealthState.missing);
    expect(python.detail, contains('Installation requise'));
  });

  test('binaire présent mais code non nul → error', () async {
    final report = await service(
      binaries: {
        'python': const ProcessResult(exitCode: 2, stderr: 'bad'),
      },
    ).run();
    final python = report.checks.firstWhere((c) => c.component == 'python');
    expect(python.state, HealthState.error);
  });

  test('DB et réseau KO remontent dans problems', () async {
    final report = await service(
      binaries: {
        'python': const ProcessResult(exitCode: 0),
      },
      db: false,
      net: false,
    ).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps, containsAll(['base de donnees', 'anime-sama']));
  });

  test('sonde aniskip absente par defaut (non listee)', () async {
    final report = await service(
      binaries: {'python': const ProcessResult(exitCode: 0)},
    ).run();
    final comps = report.checks.map((c) => c.component).toSet();
    expect(comps.contains('aniskip'), isFalse);
  });

  test('aniskip KO remonte dans problems quand la sonde est fournie', () async {
    final report = await service(
      binaries: {'python': const ProcessResult(exitCode: 0)},
      aniSkip: false,
    ).run();
    final comps = report.problems.map((c) => c.component).toSet();
    expect(comps, contains('aniskip'));
  });
}
