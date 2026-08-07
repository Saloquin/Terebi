import 'package:test/test.dart';
import 'package:terebi/src/services/title_utils.dart';

void main() {
  group('cleanSearchTitle', () {
    test('retire « Saison N » / « Season N »', () {
      expect(cleanSearchTitle('Dr Stone Saison 2'), 'Dr Stone');
      expect(cleanSearchTitle('Bleach Season 3'), 'Bleach');
    });
    test('retire « Nth Season »', () {
      expect(cleanSearchTitle('Overlord 2nd Season'), 'Overlord');
    });
    test('retire « Part N »', () {
      expect(cleanSearchTitle('Attack on Titan Part 2'), 'Attack on Titan');
    });
    test('retire un sous-titre après « : »', () {
      expect(cleanSearchTitle("Fate/stay night: Heaven's Feel"), 'Fate/stay night');
    });
    test('laisse un titre simple intact', () {
      expect(cleanSearchTitle('One Piece'), 'One Piece');
    });
  });

  group('parseSeasonFromTitle', () {
    test('« Saison N » → base + N', () {
      expect(parseSeasonFromTitle('Dr Stone Saison 2'),
          const TitleSeason('Dr Stone', 2));
    });
    test('« Season N » → base + N', () {
      expect(parseSeasonFromTitle('Bleach Season 3'),
          const TitleSeason('Bleach', 3));
    });
    test('« Nth Season » → base + N', () {
      expect(parseSeasonFromTitle('Overlord 2nd Season'),
          const TitleSeason('Overlord', 2));
    });
    test('« Season IV » (romain) → base + 4', () {
      expect(parseSeasonFromTitle('Kingdom Season IV'),
          const TitleSeason('Kingdom', 4));
    });
    test('sans saison → saison 1', () {
      expect(parseSeasonFromTitle('One Piece'),
          const TitleSeason('One Piece', 1));
    });
  });
}
