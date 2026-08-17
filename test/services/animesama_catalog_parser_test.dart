import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_catalog_parser.dart';
import 'package:test/test.dart';

/// Lit un fichier en UTF-8 explicite (les fixtures anime-sama sont en UTF-8,
/// comme le Python `requests.text`).
String _readUtf8(String path) => utf8.decode(File(path).readAsBytesSync());

void main() {
  final exp = () {
    final f = File('test/fixtures/actions.expected.json');
    return f.existsSync()
        ? jsonDecode(_readUtf8('test/fixtures/actions.expected.json'))
            as Map<String, dynamic>
        : null;
  }();

  group('normalizeGenres', () {
    test('recolle Science-Fiction et déduplique', () {
      expect(normalizeGenres(['Science', 'Fiction', 'Action', 'action']),
          ['Science-Fiction', 'Action']);
    });
    test('décode les entités HTML', () {
      expect(normalizeGenres(['Com&amp;die']), ['Com&die']);
    });
    test('Fiction orpheline = bruit ignoré', () {
      expect(normalizeGenres(['Fiction', 'Action']), ['Action']);
    });
  });

  group('slugFromUrl / cdnImageUrl / isScanUrl', () {
    test('slug depuis /catalogue/<slug>/', () {
      expect(slugFromUrl('/catalogue/dr-stone/saison1/vostfr/'), 'dr-stone');
      expect(slugFromUrl('rien'), '');
    });
    test('cdn cover = thumb webp, banner = jpg', () {
      expect(cdnImageUrl('dr-stone'),
          'https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/thumb/dr-stone.webp');
      expect(cdnImageUrl('dr-stone', banner: true),
          'https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/dr-stone.jpg');
    });
    test('isScanUrl détecte les pages de scans', () {
      expect(isScanUrl('/catalogue/one-piece/scan/vf/'), isTrue);
      expect(isScanUrl('/catalogue/one-piece/saison1/vostfr/'), isFalse);
    });
  });

  group('parseCatalogueDetail (équivalence Python)', () {
    test('vraie fiche Dr Stone -> même titre + genres que Python', () {
      final htmlFile = File('test/fixtures/detail_dr_stone.html');
      if (!htmlFile.existsSync() || exp == null) {
        markTestSkipped('fixtures détail absentes');
        return;
      }
      final detail = parseCatalogueDetail(
          _readUtf8('test/fixtures/detail_dr_stone.html'), 'dr-stone');
      final expDetail = (exp['detail'] as Map).cast<String, dynamic>();
      expect(detail.title, expDetail['title']);
      expect(detail.genres, (expDetail['genres'] as List).cast<String>());
    });
  });

  group('parseCards (équivalence Python)', () {
    test('vraie page catalogue Action -> mêmes cartes que Python', () {
      final htmlFile = File('test/fixtures/catalogue_action_p1.html');
      if (!htmlFile.existsSync() || exp == null) {
        markTestSkipped('fixtures catalogue absentes');
        return;
      }
      final cards = parseCards(
          _readUtf8('test/fixtures/catalogue_action_p1.html'), 'anime-sama.to');
      expect(cards.length, exp['cards_count']);
      final expCards = (exp['cards'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < cards.length; i++) {
        expect(cards[i].title, expCards[i]['title'], reason: 'title[$i]');
        expect(cards[i].slug, expCards[i]['slug'], reason: 'slug[$i]');
        expect(cards[i].genres, (expCards[i]['genres'] as List).cast<String>(),
            reason: 'genres[$i]');
      }
    });
  });

  group('parsePlanning (équivalence Python)', () {
    test('vrai planning VOSTFR -> mêmes items (jour/titre/url/slug)', () {
      final htmlFile = File('test/fixtures/planning.html');
      if (!htmlFile.existsSync() || exp == null) {
        markTestSkipped('fixtures planning absentes');
        return;
      }
      // formatTime non testé ici (dépend du fuseau) : la vérité Python n'inclut
      // pas l'heure, on compare jour/titre/url/slug.
      final items = parsePlanning(
        _readUtf8('test/fixtures/planning.html'),
        formatTime: (ts) => '?',
      );
      expect(items.length, exp['planning_count']);
      final expItems = (exp['planning_items'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < items.length; i++) {
        expect(items[i].day, expItems[i]['day'], reason: 'day[$i]');
        expect(items[i].title, expItems[i]['title'], reason: 'title[$i]');
        expect(items[i].url, expItems[i]['url'], reason: 'url[$i]');
        expect(items[i].slug, expItems[i]['slug'], reason: 'slug[$i]');
      }
    });
  });

  group('catalogueUrl / catalogueLastPage / classicSlugs', () {
    test('URL filtre serveur (type Anime + genre)', () {
      expect(catalogueUrl('anime-sama.to', genre: 'Action'),
          contains('type%5B%5D=Anime'));
      expect(catalogueUrl('anime-sama.to', genre: 'Action'),
          contains('genre%5B%5D=Action'));
      expect(catalogueUrl('anime-sama.to', page: 3), contains('&page=3'));
    });
    test('dernière page depuis les liens ?page=N', () {
      expect(catalogueLastPage('a?page=1 b?page=5 c?page=3'), 5);
      expect(catalogueLastPage('aucune pagination'), 1);
    });
    test('classicSlugs contient les 58 slugs du Python', () {
      expect(classicSlugs.length, 58);
      expect(classicSlugs.first, 'one-piece');
      expect(classicSlugs.last, 'dr-stone');
    });
  });
}
