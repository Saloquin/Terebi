import 'package:test/test.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/services/stream_resolver.dart';
import 'package:terebi/src/services/animesama_resolver.dart';

AnimeSamaResolver _resolver(ProcessRunner runner) => AnimeSamaResolver(
      pythonPath: 'python',
      wrapperScriptPath: r'C:\app\animesama_resolve.py',
      animeSamaScriptPath: r'C:\tools\anime_sama.py',
      runner: runner,
    );

Future<ProcessResult> _never(String e, List<String> a,
        {Map<String, String>? environment}) async =>
    throw StateError('ne doit pas être appelé');

void main() {
  group('buildArgs', () {
    final r = _resolver(_never);

    test('VOSTFR : titre nettoyé, saison, épisode, pas de --vf', () {
      expect(
        r.buildArgs(title: 'Dr Stone Saison 2', episode: 3, season: 2),
        [
          r'C:\app\animesama_resolve.py',
          '--script', r'C:\tools\anime_sama.py',
          '--title', 'Dr Stone',
          '--season', '2',
          '--episode', '3',
        ],
      );
    });

    test('VF : ajoute --vf', () {
      final args = r.buildArgs(
          title: 'Naruto', episode: 1, season: 1, language: PlaybackLanguage.vf);
      expect(args.contains('--vf'), isTrue);
      expect(args.sublist(args.length - 1), ['--vf']);
    });
  });

  group('parsing sortie wrapper', () {
    final r = _resolver(_never);

    test('parseResolvedUrl extrait l\'URL', () {
      const out = 'Tentative...\nRESOLVED_URL: https://x.sibnet.ru/a.mp4?st=1\n';
      expect(r.parseResolvedUrl(out), 'https://x.sibnet.ru/a.mp4?st=1');
    });

    test('parseError extrait le message', () {
      const out = 'RESOLVE_ERROR: épisode 5 indisponible';
      expect(r.parseError(out), 'épisode 5 indisponible');
    });

    test('parseResolvedUrl null si absent', () {
      expect(r.parseResolvedUrl('rien'), isNull);
    });
  });

  group('resolveStreamUrl', () {
    test('succès : renvoie l\'URL, passe les bons args', () async {
      List<String>? captured;
      final r = _resolver((exe, args, {Map<String, String>? environment}) async {
        captured = args;
        return const ProcessResult(
            exitCode: 0, stdout: 'RESOLVED_URL: https://x/a.mp4');
      });
      final url = await r.resolveStreamUrl(title: 'Dr Stone', episode: 1, season: 2);
      expect(url, 'https://x/a.mp4');
      expect(captured, containsAll(['--season', '2', '--episode', '1', '--title', 'Dr Stone']));
    });

    test('échec : lève ResolveException avec le message du wrapper', () async {
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          const ProcessResult(exitCode: 1, stdout: 'RESOLVE_ERROR: aucun anime trouvé'));
      expect(
        () => r.resolveStreamUrl(title: 'zzz', episode: 1),
        throwsA(isA<ResolveException>().having(
            (e) => e.message, 'message', contains('aucun anime'))),
      );
    });

    test('échec lancement Python : ResolveException', () async {
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          throw Exception('python not found'));
      expect(
        () => r.resolveStreamUrl(title: 'x', episode: 1),
        throwsA(isA<ResolveException>()),
      );
    });
  });
}
