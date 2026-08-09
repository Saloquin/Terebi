/// Tests de l'identité anime-sama (animeSamaIdFor).
library;

import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/anime_id.dart';
import 'package:terebi/src/domain/models/media.dart';

void main() {
  group('animeSamaIdFor', () {
    test('est déterministe (même titre → même id)', () {
      expect(animeSamaIdFor('Dr Stone'), animeSamaIdFor('Dr Stone'));
    });

    test('ignore casse/espaces/ponctuation (normalisation)', () {
      expect(animeSamaIdFor('Dr. Stone'), animeSamaIdFor('dr stone'));
      expect(animeSamaIdFor('One  Piece'), animeSamaIdFor('onepiece'));
    });

    test('est toujours strictement négatif (jamais 0, jamais positif)', () {
      for (final t in ['Naruto', 'Bleach', '', 'a', 'Zzz 2024']) {
        expect(animeSamaIdFor(t), lessThan(0), reason: 'titre="$t"');
      }
    });

    test('titres différents → ids différents (pas de collision triviale)', () {
      final ids = {
        animeSamaIdFor('Naruto'),
        animeSamaIdFor('Bleach'),
        animeSamaIdFor('One Piece'),
        animeSamaIdFor('Dr Stone'),
        animeSamaIdFor('Fate'),
      };
      expect(ids.length, 5);
    });

    test('ne peut pas entrer en collision avec un anilistId réel (positif)', () {
      expect(animeSamaIdFor('Naruto'), isNot(greaterThanOrEqualTo(0)));
    });
  });

  group('Media.fromAnimeSama', () {
    test('construit un Media avec id négatif stable + animeSamaTitle', () {
      final m = Media.fromAnimeSama(title: 'Dr Stone');
      expect(m.anilistId, animeSamaIdFor('Dr Stone'));
      expect(m.anilistId, lessThan(0));
      expect(m.animeSamaTitle, 'Dr Stone');
      expect(m.title.preferred, 'Dr Stone');
    });

    test('round-trip JSON conserve animeSamaTitle', () {
      final m = Media.fromAnimeSama(title: 'One Piece', coverUrl: 'http://x/c.jpg');
      final back = Media.fromJson(m.toJson());
      expect(back.anilistId, m.anilistId);
      expect(back.animeSamaTitle, 'One Piece');
      expect(back.coverUrl, 'http://x/c.jpg');
    });
  });

  group('titlesSimilar (garde-fou anti mauvais-match)', () {
    test('titres identiques → similaires', () {
      expect(titlesSimilar('Demon Slayer', 'Demon Slayer'), isTrue);
    });

    test('inclusion / suffixe de saison → similaires', () {
      expect(titlesSimilar('Demon Slayer', 'Demon Slayer: Mugen Train'), isTrue);
      expect(titlesSimilar('Dr Stone', 'Dr. Stone Season 3'), isTrue);
    });

    test('titres sans rapport → NON similaires (demon slayer vs onigiri)', () {
      expect(titlesSimilar('Demon Slayer', 'Onigiri'), isFalse);
      expect(titlesSimilar('The Brilliant Healer', 'Naruto'), isFalse);
    });

    test('chevauchement partiel insuffisant → NON similaire', () {
      expect(titlesSimilar('Attack on Titan', 'Attack'), isTrue); // inclusion
      expect(titlesSimilar('One Piece', 'Two Pieces of Cake'), isFalse);
    });
  });

  group('enrichedWith', () {
    test('garde l\'identité anime-sama, prend cover/description AniList', () {
      final sama = Media.fromAnimeSama(title: 'Demon Slayer');
      final anilist = Media(
        anilistId: 999, // vrai id AniList — NE DOIT PAS être adopté
        title: const MediaTitle(english: 'Onigiri'),
        coverUrl: 'http://a/cover.jpg',
        description: 'desc',
      );
      final merged = sama.enrichedWith(anilist);
      expect(merged.anilistId, sama.anilistId); // identité conservée
      expect(merged.animeSamaTitle, 'Demon Slayer');
      expect(merged.title.preferred, 'Demon Slayer'); // titre conservé
      expect(merged.coverUrl, 'http://a/cover.jpg'); // image AniList
      expect(merged.description, 'desc');
    });
  });
}
