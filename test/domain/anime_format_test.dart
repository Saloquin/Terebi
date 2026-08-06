import 'package:test/test.dart';
import 'package:terebi/src/domain/models/anime_format.dart';

void main() {
  group('animeFormatFromAniList', () {
    test('mappe les valeurs AniList connues', () {
      expect(animeFormatFromAniList('TV'), AnimeFormat.tv);
      expect(animeFormatFromAniList('MOVIE'), AnimeFormat.movie);
      expect(animeFormatFromAniList('OVA'), AnimeFormat.ova);
      expect(animeFormatFromAniList('ONA'), AnimeFormat.ona);
      expect(animeFormatFromAniList('SPECIAL'), AnimeFormat.special);
    });

    test('retourne unknown pour null ou valeur inconnue', () {
      expect(animeFormatFromAniList(null), AnimeFormat.unknown);
      expect(animeFormatFromAniList('BLURAY'), AnimeFormat.unknown);
    });
  });
}
