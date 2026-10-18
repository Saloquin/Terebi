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

  group('Refonte Anime-Sama (.oe-* & .as-carte)', () {
    test('parseCatalogueDetail extrait toutes les nouvelles métadonnées', () {
      final file = File('test/fixtures/detail_redesign.html');
      if (!file.existsSync()) {
        markTestSkipped('fixture detail_redesign.html absente');
        return;
      }
      final detail = parseCatalogueDetail(
        _readUtf8('test/fixtures/detail_redesign.html'),
        'the-exiled-heavy-knight-knows-how-to-game-the-system',
      );

      expect(detail.title,
          'The Exiled Heavy Knight Knows How to Game the System');
      expect(
          detail.alternativeTitles,
          contains('Tsuihou Sareta Tensei Juukishi wa Game Chishiki de Musou Suru'));
      expect(detail.synopsis, contains('Lors de la Cérémonie'));
      expect(detail.genres, contains('Action'));
      expect(detail.genres, contains('Fantasy'));
      expect(detail.genres, contains('Isekai'));

      // Images HD
      expect(detail.posterUrl,
          'https://image.tmdb.org/t/p/w342/flcyEjfwHECnqgXMGNZsajLg1rv.jpg');
      expect(
          detail.bannerUrl,
          'https://cdn.jsdelivr.net/gh/Anime-Sama/IMG@img/contenu/the-exiled-heavy-knight-knows-how-to-game-the-system.jpg');

      // Notes et IDs externes
      expect(detail.score, 6.8);
      expect(detail.anilistId, 180136);
      expect(detail.malId, 59741);
      expect(detail.tmdbId, 270603);
      expect(detail.korboUrl, contains('korbo.fr/oeuvre/'));
      expect(detail.trailerYoutubeId, 'ZyJA7hswtv0');

      // Métadonnées dl.oe-infos
      expect(detail.format, 'Série TV');
      expect(detail.status, 'En cours');
      expect(detail.releaseDate, '3 juil. 2026');
      expect(detail.seasonPeriod, 'Été 2026');
      expect(detail.totalEpisodes, 26);
      expect(detail.studio, 'GoHands');
      expect(detail.broadcastChannels, 'MBS, TBS');
      expect(detail.authors, contains('Nekoko'));

      // Prochain épisode
      expect(detail.nextEpisodeNumber, 17);
      expect(detail.nextEpisodeTimestamp, 1792682760);
      expect(detail.nextEpisodeDateText, contains('22/10/2026'));

      // Similaires
      expect(detail.similarAnime.length, 10);
      expect(detail.similarAnime.first.slug, 'mynoghra');
      expect(detail.similarAnime.first.title, 'Mynoghra');
    });

    test('parseCards extrait les cartes .as-carte du nouveau catalogue', () {
      final file = File('test/fixtures/catalogue_redesign.html');
      if (!file.existsSync()) {
        markTestSkipped('fixture catalogue_redesign.html absente');
        return;
      }
      final cards = parseCards(
        _readUtf8('test/fixtures/catalogue_redesign.html'),
        'anime-sama.to',
      );

      expect(cards.length, greaterThanOrEqualTo(30));
      expect(cards.any((c) => c.slug == 'zombie-sagashitemasu'), isTrue);
      expect(cards.any((c) => c.slug == 'tis-time-for-torture-princess'), isTrue);
      expect(cards.any((c) => c.slug == '07-ghost'), isTrue);
      // Vérifie que les scans purs sont exclus
      expect(cards.any((c) => c.slug == '100-jours-avant-ta-mort'), isFalse);
    });
  });
}
