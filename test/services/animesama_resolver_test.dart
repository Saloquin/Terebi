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

    test('VOSTFR : action resolve, titre nettoyé, saison, épisode, pas de --vf', () {
      final args = r.buildArgs(title: 'Dr Stone Saison 2', episode: 3, season: 2);
      expect(args, containsAllInOrder(['--action', 'resolve']));
      expect(args, containsAllInOrder(['--title', 'Dr Stone']));
      expect(args, containsAllInOrder(['--season', '2']));
      expect(args, containsAllInOrder(['--episode', '3']));
      expect(args.contains('--vf'), isFalse);
    });

    test('VF : ajoute --vf', () {
      final args = r.buildArgs(
          title: 'Naruto', episode: 1, season: 1, language: PlaybackLanguage.vf);
      expect(args.contains('--vf'), isTrue);
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

  group('listSeasons', () {
    const seasonsOut =
        'SEASONS_JSON: [{"index":1,"name":"Saison 1"},{"index":2,"name":"Saison 2"},{"index":3,"name":"OAV"}]';

    test('parse la liste des saisons', () async {
      List<String>? captured;
      final r = _resolver((exe, args, {Map<String, String>? environment}) async {
        captured = args;
        return const ProcessResult(exitCode: 0, stdout: seasonsOut);
      });
      final seasons = await r.listSeasons(title: 'Dr Stone Saison 2');
      expect(seasons.length, 3);
      expect(seasons[1], const AnimeSamaSeason(index: 2, name: 'Saison 2'));
      expect(captured, containsAllInOrder(['--action', 'list-seasons']));
      expect(captured, containsAllInOrder(['--title', 'Dr Stone']));
    });

    test('lève ResolveException si erreur', () async {
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          const ProcessResult(exitCode: 1, stdout: 'RESOLVE_ERROR: aucun anime trouvé'));
      expect(() => r.listSeasons(title: 'zzz'),
          throwsA(isA<ResolveException>()));
    });
  });

  group('listEpisodes', () {
    test('parse les numéros d\'épisode et passe l\'index de saison', () async {
      List<String>? captured;
      final r = _resolver((exe, args, {Map<String, String>? environment}) async {
        captured = args;
        return const ProcessResult(
            exitCode: 0, stdout: 'EPISODES_JSON: ["1","2","3"]');
      });
      final eps = await r.listEpisodes(title: 'Dr Stone', seasonIndex: 2);
      expect(eps, [1, 2, 3]);
      expect(captured, containsAllInOrder(['--action', 'list-episodes']));
      expect(captured, containsAllInOrder(['--season', '2']));
    });
  });

  group('search', () {
    test('parse le catalogue et passe la requête brute', () async {
      List<String>? captured;
      final r = _resolver((exe, args, {Map<String, String>? environment}) async {
        captured = args;
        return const ProcessResult(
            exitCode: 0,
            stdout:
                'CATALOGUE_JSON: [{"title":"Dr Stone","url":"/catalogue/dr-stone/"},'
                '{"title":"Dr Stone: Stone Wars","url":"/catalogue/dr-stone/"}]');
      });
      final items = await r.search(query: 'dr stone');
      expect(items.length, 2);
      expect(items.first,
          const AnimeSamaCatalogueItem(title: 'Dr Stone', url: '/catalogue/dr-stone/'));
      expect(captured, containsAllInOrder(['--action', 'search']));
      // La requête n'est PAS nettoyée (pas de cleanSearchTitle ici).
      expect(captured, containsAllInOrder(['--title', 'dr stone']));
    });

    test('liste vide si aucun résultat (pas d\'exception)', () async {
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          const ProcessResult(exitCode: 0, stdout: 'CATALOGUE_JSON: []'));
      final items = await r.search(query: 'zzzz');
      expect(items, isEmpty);
    });

    test('lève ResolveException sur RESOLVE_ERROR', () async {
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          const ProcessResult(exitCode: 1, stdout: 'RESOLVE_ERROR: catalogue KO'));
      expect(() => r.search(query: 'x'),
          throwsA(isA<ResolveException>()));
    });
  });

  group('planning', () {
    const out =
        'PLANNING_JSON: [{"day":"Lundi","time":"18h00","title":"Dr Stone","url":"/catalogue/dr-stone/"},'
        '{"day":"Mardi","time":"","title":"One Piece","url":"/catalogue/one-piece/"}]';

    test('parse les items jour/heure/titre/url', () async {
      List<String>? captured;
      final r = _resolver((exe, args, {Map<String, String>? environment}) async {
        captured = args;
        return const ProcessResult(exitCode: 0, stdout: out);
      });
      final items = await r.planning();
      expect(items.length, 2);
      expect(items.first,
          const AnimeSamaPlanningItem(
              day: 'Lundi',
              time: '18h00',
              title: 'Dr Stone',
              url: '/catalogue/dr-stone/'));
      expect(items[1].time, ''); // heure inconnue tolérée
      expect(captured, containsAllInOrder(['--action', 'planning']));
    });

    test('lève ResolveException si planning vide/erreur', () async {
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          const ProcessResult(exitCode: 1, stdout: 'RESOLVE_ERROR: planning KO'));
      expect(() => r.planning(), throwsA(isA<ResolveException>()));
    });

    test('déduplique les doublons VF/VOSTFR du même jour', () async {
      const dup =
          'PLANNING_JSON: [{"day":"Lundi","time":"18h00","title":"Naruto VOSTFR","url":"/catalogue/naruto/vostfr/"},'
          '{"day":"Lundi","time":"18h00","title":"Naruto VF","url":"/catalogue/naruto/vf/"},'
          '{"day":"Mardi","time":"","title":"Naruto VOSTFR","url":"/catalogue/naruto/vostfr/"}]';
      final r = _resolver((exe, args, {Map<String, String>? environment}) async =>
          const ProcessResult(exitCode: 0, stdout: dup));
      final items = await r.planning();
      // Lundi : un seul Naruto (VF/VOSTFR fusionnés) ; Mardi : un autre.
      expect(items.length, 2);
      expect(items.where((i) => i.day == 'Lundi').length, 1);
      // Le suffixe de version est retiré du titre affiché.
      expect(items.first.title, 'Naruto');
    });
  });
}
