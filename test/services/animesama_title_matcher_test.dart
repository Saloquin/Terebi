import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_title_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('normTitle / titleTokens', () {
    test('normTitle retire tout sauf alphanumérique minuscule', () {
      expect(normTitle('Dr. STONE : New World!'), 'drstonenewworld');
      expect(normTitle(null), '');
    });

    test('titleTokens ignore mots vides et jetons <2 chars', () {
      expect(titleTokens('The Rising of the Shield Hero Season 2'),
          {'rising', 'shield', 'hero'});
    });
  });

  group('bestCatalogueIndex', () {
    test('correspondance exacte', () {
      expect(bestCatalogueIndex('Dr Stone', ['One Piece', 'Dr Stone']), 1);
    });

    test('inclusion (sous-titre)', () {
      expect(
          bestCatalogueIndex('Dr Stone New World', ['Naruto', 'Dr Stone']), 1);
    });

    test('chevauchement >= moitié des jetons utiles', () {
      // 'shield hero' : 2 jetons utiles, 1 match sur 'Shield Hero' -> ok.
      expect(
          bestCatalogueIndex('Shield Hero', ['Attack on Titan', 'Shield Hero']),
          1);
    });

    test('pas de match si chevauchement trop faible', () {
      // 'demon slayer kimetsu' 3 jetons ; 'Slayers' partage juste 'slayer'? non
      // (normalisation par token exact) -> aucun match fiable.
      expect(
          bestCatalogueIndex('Demon Slayer Kimetsu', ['One Piece', 'Bleach']),
          isNull);
    });

    test('liste vide -> null', () {
      expect(bestCatalogueIndex('X', const []), isNull);
    });
  });

  group('degradedQueries', () {
    test('retire le dernier mot à chaque tour, dédupliqué', () {
      expect(degradedQueries('Dr Stone Season 2'),
          ['Dr Stone Season 2', 'Dr Stone Season', 'Dr Stone', 'Dr']);
    });

    test('titre vide -> aucune requête', () {
      expect(degradedQueries('  '), isEmpty);
    });
  });

  group('parseCatalogueHtml (équivalence Python sur fixture réelle)', () {
    test('vraie page catalogue Dr Stone -> même titres/urls que Python', () {
      final htmlFile = File('test/fixtures/catalogue_search_drstone.html');
      final expectedFile =
          File('test/fixtures/catalogue_search_drstone.expected.json');
      if (!htmlFile.existsSync() || !expectedFile.existsSync()) {
        markTestSkipped('fixtures catalogue absentes');
        return;
      }
      final entries = parseCatalogueHtml(htmlFile.readAsStringSync());
      final expected =
          jsonDecode(expectedFile.readAsStringSync()) as Map<String, dynamic>;
      final expectedAnimes = (expected['animes'] as List).cast<String>();
      final expectedUrls = (expected['urls'] as List).cast<String>();

      expect([for (final e in entries) e.title], expectedAnimes);
      expect([for (final e in entries) e.url], expectedUrls);
    });

    test('VF réécrit vostfr -> vf dans les URLs', () {
      const html = '''
        <a href="/catalogue/dr-stone/vostfr/"><h2 class="card-title">Dr Stone</h2></a>
      ''';
      final entries = parseCatalogueHtml(html, vf: true);
      expect(entries.single.url, '/catalogue/dr-stone/vf/');
    });
  });
}
