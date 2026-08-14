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

    test('assoupli : titres longs partageant les mots significatifs → similaires', () {
      // Sous-titre / formatage différents mais mots-clés communs.
      expect(
        titlesSimilar('The Furious Princess Decided to Take Revenge',
            'Furious Princess: Revenge Arc'),
        isTrue,
      );
    });

    test('assoupli : fort préfixe commun → similaires', () {
      expect(titlesSimilar('Kaguya-sama Love is War', 'Kaguya-sama wa Kokurasetai'),
          isTrue);
    });

    test('assoupli ne casse pas le garde-fou (aucun mot-clé commun → non)', () {
      expect(titlesSimilar('Demon Slayer Kimetsu no Yaiba', 'Onigiri Princess'),
          isFalse);
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

    test('récupère nextAiringAt/Episode depuis AniList (jamais de l\'anime-sama)',
        () {
      final sama = Media.fromAnimeSama(title: 'One Piece'); // nextAiring null
      final airing = DateTime.utc(2026, 8, 15, 18, 30);
      final anilist = Media(
        anilistId: 21,
        title: const MediaTitle(romaji: 'One Piece'),
        nextAiringAt: airing,
        nextAiringEpisode: 1130,
      );
      final merged = sama.enrichedWith(anilist);
      expect(merged.nextAiringAt, airing);
      expect(merged.nextAiringEpisode, 1130);
    });
  });

  group('titleMatchScore (choix du bon résultat catalogue)', () {
    test('égalité normalisée = score maximal', () {
      expect(titleMatchScore('Naruto', 'Naruto'), 1000);
      expect(titleMatchScore('naruto', 'Naruto'), 1000); // casse ignorée
    });

    test('« naruto » : le bon résultat bat « boruto » et « shippuden »', () {
      // Cas réel : anime-sama renvoie [boruto, naruto, naruto shippuden…].
      final naruto = titleMatchScore('Naruto', 'Naruto');
      final boruto = titleMatchScore('Naruto', 'Boruto');
      final shippuden = titleMatchScore('Naruto', 'Naruto Shippuden');
      expect(naruto, greaterThan(boruto));
      expect(naruto, greaterThan(shippuden));
      // La déclinaison (préfixe commun) reste au-dessus du sans-rapport.
      expect(shippuden, greaterThan(boruto));
    });

    test('titre racine court préféré à une déclinaison plus longue', () {
      final court = titleMatchScore('One Piece', 'One Piece');
      final long = titleMatchScore('One Piece', 'One Piece Film Red');
      expect(court, greaterThan(long));
    });

    test('titres sans rapport → 0', () {
      expect(titleMatchScore('Naruto', 'Bleach'), 0);
    });

    test('query AniList plus longue incluant le titre catalogue', () {
      // AniList « Attack on Titan Season 3 » vs catalogue « Attack on Titan ».
      final s = titleMatchScore('Attack on Titan Season 3', 'Attack on Titan');
      expect(s, greaterThan(0));
    });
  });

  group('slugFromCatalogueUrl', () {
    test('extrait le slug depuis /catalogue/<slug>/', () {
      expect(slugFromCatalogueUrl('/catalogue/one-piece/'), 'one-piece');
      expect(slugFromCatalogueUrl('/catalogue/dr-stone'), 'dr-stone');
      expect(slugFromCatalogueUrl('https://anime-sama.to/catalogue/naruto/'),
          'naruto');
    });

    test('ignore les segments de langue/saison apres le slug', () {
      expect(slugFromCatalogueUrl('/catalogue/bleach/saison1/vostfr/'), 'bleach');
    });

    test('URL sans /catalogue/ -> chaine vide', () {
      expect(slugFromCatalogueUrl('/planning/'), '');
      expect(slugFromCatalogueUrl(''), '');
    });
  });

  group('animeSamaIdForSlug', () {
    test('est deterministe (meme slug -> meme id)', () {
      expect(animeSamaIdForSlug('one-piece'), animeSamaIdForSlug('one-piece'));
    });

    test('est toujours strictement positif (jamais 0, jamais negatif)', () {
      for (final s in ['one-piece', 'naruto', 'a', 'dr-stone', 'x-2024']) {
        expect(animeSamaIdForSlug(s), greaterThan(0), reason: 'slug=$s');
      }
    });

    test('slugs differents -> ids differents (pas de collision triviale)', () {
      final ids = {
        animeSamaIdForSlug('one-piece'),
        animeSamaIdForSlug('naruto'),
        animeSamaIdForSlug('bleach'),
        animeSamaIdForSlug('dr-stone'),
        animeSamaIdForSlug('fate'),
      };
      expect(ids.length, 5);
    });
  });
}
