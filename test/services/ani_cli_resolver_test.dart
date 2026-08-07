import 'package:test/test.dart';
import 'package:terebi/src/services/process_runner.dart';
import 'package:terebi/src/services/stream_resolver.dart';
import 'package:terebi/src/services/ani_cli_resolver.dart';

/// Sortie réelle capturée au spike US-00 (mode ANI_CLI_PLAYER=debug), avec
/// codes ANSI comme en conditions réelles.
const _debugOutput = '''
\x1B[2K\x1B[1;34mChecking dependencies...\x1B[0m
\x1B[1;34manidb.app links fetched\x1B[0m
All links:
1080p >https://hls.anidb.app/stream/TOKEN/index-f1-v1-a1.m3u8
720p >https://hls.anidb.app/stream/TOKEN/index-f2-v1-a1.m3u8
360p >https://hls.anidb.app/stream/TOKEN/index-f3-v1-a1.m3u8
Selected link:
https://hls.anidb.app/stream/TOKEN/index-f1-v1-a1.m3u8
''';

void main() {
  group('AniCliResolver.buildArgs', () {
    const resolver = AniCliResolver(runner: _neverRun);

    test('VOSTFR : -S 1 -e <n> puis titre, pas de --dub', () {
      expect(
        resolver.buildArgs(title: 'One Piece', episode: 5),
        ['-S', '1', '-e', '5', 'One Piece'],
      );
    });

    test('VF : ajoute --dub', () {
      expect(
        resolver.buildArgs(title: 'Naruto', episode: 12, language: PlaybackLanguage.vf),
        ['-S', '1', '-e', '12', '--dub', 'Naruto'],
      );
    });

    test('nettoie le suffixe de saison du titre', () {
      expect(
        resolver.buildArgs(title: 'Clevatess Saison 2', episode: 3),
        ['-S', '1', '-e', '3', 'Clevatess'],
      );
    });
  });

  group('mode shell (Windows)', () {
    test('sans shell : exécute ani-cli directement', () async {
      String? capturedExe;
      List<String>? capturedArgs;
      final resolver = AniCliResolver(
        aniCliPath: 'ani-cli',
        runner: (exe, args, {Map<String, String>? environment}) async {
          capturedExe = exe;
          capturedArgs = args;
          return const ProcessResult(exitCode: 0, stdout: _debugOutput);
        },
      );
      await resolver.resolveStreamUrl(title: 'X', episode: 1);
      expect(capturedExe, 'ani-cli');
      expect(capturedArgs, ['-S', '1', '-e', '1', 'X']);
    });

    test('avec shell : exécute sh <script> <args>', () async {
      String? capturedExe;
      List<String>? capturedArgs;
      final resolver = AniCliResolver(
        aniCliPath: r'C:\Users\me\bin\ani-cli',
        shell: r'C:\Program Files\Git\usr\bin\sh.exe',
        runner: (exe, args, {Map<String, String>? environment}) async {
          capturedExe = exe;
          capturedArgs = args;
          return const ProcessResult(exitCode: 0, stdout: _debugOutput);
        },
      );
      await resolver.resolveStreamUrl(title: 'X', episode: 1);
      expect(capturedExe, r'C:\Program Files\Git\usr\bin\sh.exe');
      expect(capturedArgs, [r'C:\Users\me\bin\ani-cli', '-S', '1', '-e', '1', 'X']);
    });
  });

  group('parsing de la sortie debug (spike US-00)', () {
    const resolver = AniCliResolver(runner: _neverRun);

    test('parseSelectedLink extrait l\'URL après « Selected link: »', () {
      expect(
        resolver.parseSelectedLink(_debugOutput),
        'https://hls.anidb.app/stream/TOKEN/index-f1-v1-a1.m3u8',
      );
    });

    test('parseQualityLinks liste les qualités et URLs', () {
      final links = resolver.parseQualityLinks(_debugOutput);
      expect(links.length, 3);
      expect(links.first.quality, '1080p');
      expect(links.first.url, endsWith('index-f1-v1-a1.m3u8'));
      expect(links[1].quality, '720p');
    });

    test('parseSelectedLink retourne null si absent', () {
      expect(resolver.parseSelectedLink('rien ici'), isNull);
    });
  });

  group('resolveStreamUrl', () {
    test('passe ANI_CLI_PLAYER=debug et renvoie l\'URL sélectionnée', () async {
      Map<String, String>? capturedEnv;
      List<String>? capturedArgs;
      final resolver = AniCliResolver(
        runner: (exe, args, {Map<String, String>? environment}) async {
          capturedEnv = environment;
          capturedArgs = args;
          return ProcessResult(exitCode: 0, stdout: _debugOutput);
        },
      );

      final url = await resolver.resolveStreamUrl(title: 'cowboy bebop', episode: 1);

      expect(url, 'https://hls.anidb.app/stream/TOKEN/index-f1-v1-a1.m3u8');
      expect(capturedEnv?['ANI_CLI_PLAYER'], 'debug');
      expect(capturedArgs, containsAll(['-S', '1', '-e', '1', 'cowboy bebop']));
    });

    test('repli sur la première qualité si « Selected link: » absent', () async {
      const partial = 'All links:\n1080p >https://x/a.m3u8\n720p >https://x/b.m3u8\n';
      final resolver = AniCliResolver(
        runner: (exe, args, {Map<String, String>? environment}) async =>
            const ProcessResult(exitCode: 0, stdout: partial),
      );
      expect(await resolver.resolveStreamUrl(title: 't', episode: 1),
          'https://x/a.m3u8');
    });

    test('lève ResolveException si aucune URL', () async {
      final resolver = AniCliResolver(
        runner: (exe, args, {Map<String, String>? environment}) async =>
            const ProcessResult(exitCode: 1, stderr: 'No results found'),
      );
      expect(
        () => resolver.resolveStreamUrl(title: 'inconnu', episode: 1),
        throwsA(isA<ResolveException>()),
      );
    });

    test('lève ResolveException si le binaire est introuvable', () async {
      final resolver = AniCliResolver(
        runner: (exe, args, {Map<String, String>? environment}) async =>
            throw Exception('not found'),
      );
      expect(
        () => resolver.resolveStreamUrl(title: 't', episode: 1),
        throwsA(isA<ResolveException>()),
      );
    });
  });

  group('AniCliResolver.play (fallback lecteur externe)', () {
    test('succès si exit 0', () async {
      final resolver = AniCliResolver(
        runner: (exe, args, {Map<String, String>? environment}) async =>
            const ProcessResult(exitCode: 0, stdout: 'Playing...'),
      );
      expect(await resolver.play(title: 'Bleach', episode: 3), isTrue);
    });

    test('lève ResolveException si exit non nul', () async {
      final resolver = AniCliResolver(
        runner: (exe, args, {Map<String, String>? environment}) async =>
            const ProcessResult(exitCode: 1, stderr: 'no results'),
      );
      expect(
        () => resolver.play(title: 'Inconnu', episode: 1),
        throwsA(isA<ResolveException>()),
      );
    });
  });
}

Future<ProcessResult> _neverRun(
  String e,
  List<String> a, {
  Map<String, String>? environment,
}) async =>
    throw StateError('ne doit pas être appelé');
