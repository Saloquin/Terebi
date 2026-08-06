import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/franchise_service.dart';
import 'package:terebi/src/domain/models/anime_format.dart';
import 'package:terebi/src/domain/models/enums.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';
import 'package:terebi/src/domain/models/media.dart';
import 'package:terebi/src/domain/models/media_relation.dart';

void main() {
  const svc = FranchiseService();

  Media media(int id, {int? year, ReleaseStatus status = ReleaseStatus.finished}) =>
      Media(
        anilistId: id,
        title: MediaTitle(romaji: 'M$id'),
        format: AnimeFormat.tv,
        status: status,
        seasonYear: year,
      );

  ListEntry entry(int id, ListStatus status) =>
      ListEntry(mediaId: id, status: status, updatedAt: DateTime.utc(2020));

  FranchiseItem item(int id, {int? year, ReleaseStatus status = ReleaseStatus.finished, ListStatus? tracked}) =>
      FranchiseItem(
        media: media(id, year: year, status: status),
        entry: tracked == null ? null : entry(id, tracked),
      );

  group('ordered', () {
    test('trie par année puis id', () {
      final r = svc.ordered([
        item(3, year: 2021),
        item(1, year: 2019),
        item(2, year: 2019),
      ]);
      expect(r.map((i) => i.media.anilistId).toList(), [1, 2, 3]);
    });

    test('items sans année vont à la fin', () {
      final r = svc.ordered([item(5), item(1, year: 2020)]);
      expect(r.first.media.anilistId, 1);
      expect(r.last.media.anilistId, 5);
    });
  });

  group('isFranchiseCompleted', () {
    test('vrai si tous COMPLETED', () {
      expect(
        svc.isFranchiseCompleted([
          item(1, tracked: ListStatus.completed),
          item(2, tracked: ListStatus.completed),
        ]),
        isTrue,
      );
    });
    test('faux si un non suivi', () {
      expect(
        svc.isFranchiseCompleted([
          item(1, tracked: ListStatus.completed),
          item(2),
        ]),
        isFalse,
      );
    });
    test('faux si liste vide', () {
      expect(svc.isFranchiseCompleted([]), isFalse);
    });
  });

  group('sequelsToReplan (US-46)', () {
    test('propose la suite RELEASING d\'un média COMPLETED non suivie', () {
      final items = [
        item(1, tracked: ListStatus.completed),
        item(2, status: ReleaseStatus.releasing), // suite non suivie
      ];
      final rels = [
        const MediaRelation(mediaId: 1, relatedMediaId: 2, type: RelationType.sequel),
      ];
      expect(svc.sequelsToReplan(items: items, relations: rels), {2});
    });

    test('ne propose pas si la suite est déjà suivie', () {
      final items = [
        item(1, tracked: ListStatus.completed),
        item(2, status: ReleaseStatus.releasing, tracked: ListStatus.planning),
      ];
      final rels = [
        const MediaRelation(mediaId: 1, relatedMediaId: 2, type: RelationType.sequel),
      ];
      expect(svc.sequelsToReplan(items: items, relations: rels), isEmpty);
    });

    test('propose si la suite avait été DROPPED', () {
      final items = [
        item(1, tracked: ListStatus.completed),
        item(2, status: ReleaseStatus.releasing, tracked: ListStatus.dropped),
      ];
      final rels = [
        const MediaRelation(mediaId: 1, relatedMediaId: 2, type: RelationType.sequel),
      ];
      expect(svc.sequelsToReplan(items: items, relations: rels), {2});
    });

    test('ne propose pas si le média source n\'est pas COMPLETED', () {
      final items = [
        item(1, tracked: ListStatus.current),
        item(2, status: ReleaseStatus.releasing),
      ];
      final rels = [
        const MediaRelation(mediaId: 1, relatedMediaId: 2, type: RelationType.sequel),
      ];
      expect(svc.sequelsToReplan(items: items, relations: rels), isEmpty);
    });

    test('ignore les relations non-SEQUEL', () {
      final items = [
        item(1, tracked: ListStatus.completed),
        item(2, status: ReleaseStatus.releasing),
      ];
      final rels = [
        const MediaRelation(mediaId: 1, relatedMediaId: 2, type: RelationType.sideStory),
      ];
      expect(svc.sequelsToReplan(items: items, relations: rels), isEmpty);
    });
  });
}
