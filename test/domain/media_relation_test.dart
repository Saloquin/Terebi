import 'package:test/test.dart';
import 'package:terebi/src/domain/models/media_relation.dart';

void main() {
  group('RelationType.fromAniList', () {
    test('mappe toutes les valeurs connues', () {
      expect(RelationType.fromAniList('SEQUEL'), RelationType.sequel);
      expect(RelationType.fromAniList('PREQUEL'), RelationType.prequel);
      expect(RelationType.fromAniList('SIDE_STORY'), RelationType.sideStory);
      expect(RelationType.fromAniList('PARENT'), RelationType.parent);
      expect(RelationType.fromAniList('ALTERNATIVE'), RelationType.alternative);
      expect(RelationType.fromAniList('SPIN_OFF'), RelationType.spinOff);
    });

    test('valeur inconnue ou null → other', () {
      expect(RelationType.fromAniList('SUMMARY'), RelationType.other);
      expect(RelationType.fromAniList('CHARACTER'), RelationType.other);
      expect(RelationType.fromAniList(null), RelationType.other);
    });
  });

  group('RelationType.anilist', () {
    test('retourne les valeurs AniList correctes', () {
      expect(RelationType.sequel.anilist, 'SEQUEL');
      expect(RelationType.prequel.anilist, 'PREQUEL');
      expect(RelationType.sideStory.anilist, 'SIDE_STORY');
      expect(RelationType.parent.anilist, 'PARENT');
      expect(RelationType.alternative.anilist, 'ALTERNATIVE');
      expect(RelationType.spinOff.anilist, 'SPIN_OFF');
      expect(RelationType.other.anilist, 'OTHER');
    });
  });

  group('MediaRelation round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = MediaRelation(
        mediaId: 1,
        relatedMediaId: 2,
        type: RelationType.sequel,
      );

      final restored = MediaRelation.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.relatedMediaId, original.relatedMediaId);
      expect(restored.type, original.type);
    });

    test('round-trip pour chaque type de relation', () {
      for (final type in RelationType.values) {
        final relation = MediaRelation(
          mediaId: 10,
          relatedMediaId: 20,
          type: type,
        );
        final restored = MediaRelation.fromJson(relation.toJson());
        expect(restored.type, type, reason: 'type $type non préservé');
      }
    });
  });
}
