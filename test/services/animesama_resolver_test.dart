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

    test('VOSTFR : action resolve, titre TEL QUEL, saison, épisode, pas de --vf', () {
      final args = r.buildArgs(title: 'Dr Stone Saison 2', episode: 3, season: 2);
      expect(args, containsAllInOrder(['--action', 'resolve']));
      // Le titre est passé tel quel (anime-sama = source de vérité, pas de
      // nettoyage type AniList qui casserait les titres longs / sous-titres).
      expect(args, containsAllInOrder(['--title', 'Dr Stone Saison 2']));
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
      // Titre passé tel quel (pas de nettoyage).
      expect(captured, containsAllInOrder(['--title', 'Dr Stone Saison 2']));
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
          const AnimeSamaCatalogueItem(title: 'Dr Stone', url: '/catalogue/dr-stone/', slug: 'dr-stone'));
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

  group('AnimeSamaCatalogueItem enrichi', () {
    test('porte slug, cover et genres', () {
      const it = AnimeSamaCatalogueItem(
        title: 'One Piece',
        url: '/catalogue/one-piece/',
        slug: 'one-piece',
        cover: 'https://cdn/one-piece.jpg',
        genres: ['Action', 'Aventure'],
      );
      expect(it.slug, 'one-piece');
      expect(it.cover, 'https://cdn/one-piece.jpg');
      expect(it.genres, ['Action', 'Aventure']);
    });

    test('slug/cover/genres ont des valeurs par defaut', () {
      const it = AnimeSamaCatalogueItem(title: 'X', url: '/catalogue/x/');
      expect(it.slug, '');
      expect(it.cover, isNull);
      expect(it.genres, isEmpty);
    });
  });

  group('AnimeSamaDetail', () {
    test('porte les champs enrichis', () {
      const d = AnimeSamaDetail(
        slug: 'one-piece',
        title: 'One Piece',
        synopsis: 'Un pirate...',
        genres: ['Action'],
        cover: 'https://cdn/c.jpg',
        banner: 'https://cdn/b.jpg',
      );
      expect(d.slug, 'one-piece');
      expect(d.synopsis, 'Un pirate...');
      expect(d.genres, ['Action']);
      expect(d.cover, 'https://cdn/c.jpg');
      expect(d.banner, 'https://cdn/b.jpg');
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
              url: '/catalogue/dr-stone/',
              slug: 'dr-stone'));
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

  group('parseurs enrichis', () {
    // Resolver minimal : les parseurs n'utilisent pas le runner.
    final r = AnimeSamaResolver(
      wrapperScriptPath: 'w.py',
      animeSamaScriptPath: 'a.py',
      runner: (exe, args, {Map<String, String>? environment}) async =>
          throw UnimplementedError(),
    );

    test('parseCatalogue lit le slug', () {
      const out = 'CATALOGUE_JSON: '
          '[{"title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"}]';
      final items = r.parseCatalogue(out);
      expect(items, hasLength(1));
      expect(items.first.slug, 'one-piece');
      expect(items.first.title, 'One Piece');
    });

    test('parseCatalogue derive le slug de l URL si absent', () {
      const out =
          'CATALOGUE_JSON: [{"title":"Bleach","url":"/catalogue/bleach/"}]';
      expect(r.parseCatalogue(out).first.slug, 'bleach');
    });

    test('parseCatalogue gere une URL absolue + genres (structure catalogue)', () {
      // Le scraper renvoie desormais des URLs absolues et les genres/cover reels.
      const out = 'CATALOGUE_JSON: [{'
          '"title":"86 Eighty Six",'
          '"url":"https://anime-sama.to/catalogue/86-eighty-six/",'
          '"slug":"86-eighty-six",'
          '"cover_url":"https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/thumb/86-eighty-six1.webp",'
          '"genres":["Action","Drame","Science-fiction"]}]';
      final items = r.parseCatalogue(out);
      expect(items, hasLength(1));
      expect(items.first.slug, '86-eighty-six');
      expect(items.first.cover, contains('86-eighty-six1.webp'));
      expect(items.first.genres, containsAll(['Action', 'Drame']));
    });

    test('parseDetail lit synopsis/genres/cover/banner', () {
      const out = 'DETAIL_JSON: {"slug":"one-piece","title":"One Piece",'
          '"synopsis":"Un pirate","genres":["Action","Aventure"],'
          '"cover_url":"https://cdn/c.jpg","banner_url":"https://cdn/b.jpg"}';
      final d = r.parseDetail(out);
      expect(d, isNotNull);
      expect(d!.slug, 'one-piece');
      expect(d.synopsis, 'Un pirate');
      expect(d.genres, ['Action', 'Aventure']);
      expect(d.cover, 'https://cdn/c.jpg');
      expect(d.banner, 'https://cdn/b.jpg');
    });

    test('parseDetail tolere les champs manquants', () {
      const out = 'DETAIL_JSON: {"slug":"x","title":"X"}';
      final d = r.parseDetail(out);
      expect(d!.synopsis, isNull);
      expect(d.genres, isEmpty);
      expect(d.cover, isNull);
    });

    test('parseHome lit classics et latest_episodes', () {
      const out = 'HOME_JSON: {'
          '"classics":[{"title":"Naruto","url":"/catalogue/naruto/","slug":"naruto","cover_url":"https://cdn/n.jpg","genres":["Action"]}],'
          '"latest_episodes":[{"title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"}]}';
      final h = r.parseHome(out);
      expect(h.classics, hasLength(1));
      expect(h.classics.first.title, 'Naruto');
      expect(h.classics.first.cover, 'https://cdn/n.jpg');
      expect(h.classics.first.genres, ['Action']);
      expect(h.latestEpisodes, hasLength(1));
      expect(h.latestEpisodes.first.slug, 'one-piece');
    });

    test('parsePlanning lit le slug', () {
      const out = 'PLANNING_JSON: '
          '[{"day":"Lundi","time":"18h00","title":"One Piece","url":"/catalogue/one-piece/","slug":"one-piece"}]';
      final items = r.parsePlanning(out);
      expect(items.first.slug, 'one-piece');
      expect(items.first.time, '18h00');
    });
  });
}
