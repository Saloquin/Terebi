import 'dart:convert';
import 'dart:io';

import 'package:terebi/src/services/animesama_http_client.dart';
import 'package:terebi/src/services/animesama_seasons.dart';
import 'package:test/test.dart';

void main() {
  group('parseSeasons / isRealSeason / dedupe (équivalence Python)', () {
    test('vraie page Dr Stone -> mêmes saisons brutes, is_real, dedup', () {
      final htmlFile = File('test/fixtures/anime_dr_stone.html');
      final expFile = File('test/fixtures/seasons_dr_stone.expected.json');
      if (!htmlFile.existsSync() || !expFile.existsSync()) {
        markTestSkipped('fixtures saisons absentes');
        return;
      }
      final exp = jsonDecode(expFile.readAsStringSync()) as Map<String, dynamic>;
      final raw = parseSeasons(htmlFile.readAsStringSync());

      // Saisons brutes identiques (nom + url).
      final expRaw = (exp['raw'] as List).cast<Map<String, dynamic>>();
      expect(raw.length, expRaw.length);
      for (var i = 0; i < raw.length; i++) {
        expect(raw[i].name, expRaw[i]['name']);
        expect(raw[i].url, expRaw[i]['url']);
      }

      // isRealSeason identique élément par élément.
      final expIsReal = (exp['is_real'] as List).cast<bool>();
      expect([for (final s in raw) isRealSeason(s)], expIsReal);

      // dedupe identique (sur les vraies saisons).
      final real = raw.where(isRealSeason).toList();
      final dedup = dedupeSeasons(real);
      final expDedup = (exp['dedup'] as List).cast<Map<String, dynamic>>();
      expect([for (final s in dedup) s.name],
          [for (final e in expDedup) e['name']]);
      expect([for (final s in dedup) s.url],
          [for (final e in expDedup) e['url']]);
    });

    test('parseActiveSeasons ignore les commentaires JS/HTML et garde les actifs', () {
      const html = '''
        <script>
          /*panneauAnime("nom", "url");*/
          panneauAnime("Saison 1", "saison1/vostfr");
          /*panneauAnime("Saison 2", "saison2/vostfr");
          panneauAnime("Saison 3", "saison3/vostfr");*/
          // panneauAnime("OAV", "oav/vostfr");
          <!--panneauAnime("Film", "film/vostfr");-->
          panneauAnime('Saison 4', 'saison4/vostfr');
          panneauAnime("Externe", "https://example.com/stream");
        </script>
      ''';
      final active = parseActiveSeasons(html);
      expect(
        [for (final s in active) (s.name, s.url)],
        [
          ('Saison 1', 'saison1/vostfr'),
          ('Saison 4', 'saison4/vostfr'),
          ('Externe', 'https://example.com/stream'),
        ],
      );
    });
  });

  group('isRealSeason (cas unitaires)', () {
    test('chemin relatif court = vraie saison', () {
      expect(isRealSeason(const RawSeason('Saison 1', 'saison1/vostfr')), isTrue);
      expect(isRealSeason(const RawSeason('OAV', 'oav/vf')), isTrue);
      expect(isRealSeason(const RawSeason('Saison 2 VF', 'saison2/vf1')), isTrue);
    });
    test('http/catalogue/multi-segment = reco, pas une saison', () {
      expect(isRealSeason(const RawSeason('X', 'https://autre.com/x')), isFalse);
      expect(isRealSeason(const RawSeason('X', '/catalogue/autre/')), isFalse);
      expect(isRealSeason(const RawSeason('X', 'a/b/c')), isFalse);
    });
  });

  group('urlHasId / playableEpisodeCount', () {
    test('détecte les URLs-coquilles', () {
      expect(urlHasId('https://video.sibnet.ru/shell.php?videoid='), isFalse);
      expect(urlHasId('https://ansembed.net/embed-.html'), isFalse);
      expect(urlHasId('https://vk.com/video_ext.php?oid=&hd=3'), isFalse);
      expect(urlHasId(''), isFalse);
      expect(urlHasId(','), isFalse);
      expect(urlHasId('lien:'), isFalse);
      expect(urlHasId('lien:abc'), isFalse);
      expect(urlHasId('lien:9474'), isTrue);
      expect(
          urlHasId('https://video.sibnet.ru/shell.php?videoid=6229246'), isTrue);
    });
  });

  group('parseFilever / parseEpisodesJs (équivalence Python)', () {
    test('filever = 5591 et hash hexa (ex. e20d0f7c54dd) sur la page saison', () {
      expect(parseFilever('src="episodes.js?filever=5591"'), '5591');
      expect(parseFilever("src='episodes.js?filever=e20d0f7c54dd'"),
          'e20d0f7c54dd');
      expect(parseFilever('src="episodes.js?filever=8b97a91d88f1"'),
          '8b97a91d88f1');
      expect(parseFilever('pas de filever'), isNull);
    });

    test('vrai episodes.js Dr Stone S1 -> même dict que Python', () {
      final jsFile = File('test/fixtures/episodes_dr_stone_s1.js');
      final expFile = File('test/fixtures/episodes_dr_stone_s1.expected.json');
      if (!jsFile.existsSync() || !expFile.existsSync()) {
        markTestSkipped('fixtures episodes absentes');
        return;
      }
      final eps = parseEpisodesJs(jsFile.readAsStringSync());
      final expected = (jsonDecode(expFile.readAsStringSync())
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as List).cast<String>()));

      expect(eps.length, expected.length);
      for (final key in expected.keys) {
        expect(eps[key], expected[key], reason: 'episode $key');
      }
    });

    test('Anime-sama 12/11/2026 : parsing inline data-source bdd, epsJeton, epsMeta, lecteursInfos', () async {
      const html = '''
        <html>
        <head>
          <script data-source="bdd">
            var eps1 = ["lien:9474", "lien:9477", ""];
            var eps2 = ["lien:9473", "lien:9476", ","];
            var epsMeta = {"9473":["uqload.vc"],"9474":["ansembed.net"],"9476":["uqload.vc"],"9477":["ansembed.net"]};
            var epsJeton = "309.1794686400.9339c1dbebf0627dc5463a3e";
            var epsOrdreFinal = true;
          </script>
          <script>
            var lecteursInfos = {"ansembed.net":{"nom":"Vidmoly","pub":1,"hd":true},"uqload.vc":{"nom":"Uqload"}};
          </script>
        </head>
        </html>
      ''';

      expect(parseEpsJeton(html), '309.1794686400.9339c1dbebf0627dc5463a3e');

      final meta = parseEpsMeta(html);
      expect(meta['9473'], 'uqload.vc');
      expect(meta['9474'], 'ansembed.net');

      final names = parseLecteursInfos(html);
      expect(names['ansembed.net'], 'Vidmoly');
      expect(names['uqload.vc'], 'Uqload');

      final eps = parseEpisodesJs(html);
      expect(eps['1'], ['lien:9474', 'lien:9473']);
      expect(eps['2'], ['lien:9477', 'lien:9476']);
      // Episode 3 had empty/comma -> should not have invalid links
      expect(eps['3'], isNull);

      final info = await fetchSeasonInfo(
        (url, {followRedirects = true, headers, method = HttpMethod.get, query}) async =>
            HttpResponse(statusCode: 200, body: html),
        'https://anime-sama.to/catalogue/solo-leveling/saison2/vostfr/',
      );
      expect(info.episodes.length, 2);
      expect(info.jeton, '309.1794686400.9339c1dbebf0627dc5463a3e');
      expect(info.meta['9474'], 'ansembed.net');
      expect(info.lecteurNames['ansembed.net'], 'Vidmoly');
    });
  });
}
