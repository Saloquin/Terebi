import 'package:test/test.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/services/ani_cli_resolver.dart';

void main() {
  group('AniCliResolver.buildArgs', () {
    const resolver = AniCliResolver(runner: _neverRun);

    test('VOSTFR (défaut) : -e <n> puis titre, pas de --dub', () {
      expect(
        resolver.buildArgs(title: 'One Piece', episode: 5),
        ['-e', '5', 'One Piece'],
      );
    });

    test('VF : ajoute --dub', () {
      expect(
        resolver.buildArgs(title: 'Naruto', episode: 12, language: PlaybackLanguage.vf),
        ['-e', '12', '--dub', 'Naruto'],
      );
    });
  });

  group('AniCliResolver.play', () {
    test('succès si exit 0', () async {
      var captured = <String>[];
      final resolver = AniCliResolver(
        runner: (exe, args) async {
          captured = [exe, ...args];
          return const ProcessResult(exitCode: 0, stdout: 'Playing...');
        },
      );
      final ok = await resolver.play(title: 'Bleach', episode: 3);
      expect(ok, isTrue);
      expect(captured, ['ani-cli', '-e', '3', 'Bleach']);
    });

    test('lève ResolveException si exit non nul', () async {
      final resolver = AniCliResolver(
        runner: (exe, args) async =>
            const ProcessResult(exitCode: 1, stderr: 'no results'),
      );
      expect(
        () => resolver.play(title: 'Inconnu', episode: 1),
        throwsA(isA<ResolveException>()),
      );
    });

    test('lève ResolveException si le lancement échoue (binaire absent)', () async {
      final resolver = AniCliResolver(
        runner: (exe, args) async => throw Exception('not found'),
      );
      expect(
        () => resolver.play(title: 'X', episode: 1),
        throwsA(isA<ResolveException>()),
      );
    });
  });
}

Future<ProcessResult> _neverRun(String e, List<String> a) async =>
    throw StateError('ne doit pas être appelé');
