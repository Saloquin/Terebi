import 'package:test/test.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

void main() {
  final dateFixe = DateTime.utc(2024, 1, 15, 10, 0, 0);

  group('ListEntry round-trip JSON', () {
    test('toJson → fromJson préserve tous les champs', () {
      final original = ListEntry(
        mediaId: 21,
        status: ListStatus.current,
        progress: 42,
        hiddenFromPlanning: true,
        updatedAt: dateFixe,
        totalEpisodesOnPage: 50,
      );

      final restored = ListEntry.fromJson(original.toJson());

      expect(restored.mediaId, original.mediaId);
      expect(restored.status, original.status);
      expect(restored.progress, original.progress);
      expect(restored.hiddenFromPlanning, original.hiddenFromPlanning);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.totalEpisodesOnPage, 50);
    });

    test('round-trip avec champs optionnels à leurs valeurs par défaut', () {
      final original = ListEntry(
        mediaId: 5,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );

      final restored = ListEntry.fromJson(original.toJson());

      expect(restored.progress, 0);
      expect(restored.hiddenFromPlanning, isFalse);
      expect(restored.totalEpisodesOnPage, 0);
    });
  });

  group('ListEntry.copyWith', () {
    test('copyWith remplace les champs fournis', () {
      final base = ListEntry(
        mediaId: 1,
        status: ListStatus.planning,
        progress: 0,
        updatedAt: dateFixe,
        totalEpisodesOnPage: 12,
      );

      final updated = base.copyWith(
        status: ListStatus.current,
        progress: 5,
        updatedAt: DateTime.utc(2024, 6, 1),
        totalEpisodesOnPage: 24,
      );

      expect(updated.mediaId, 1); // conservé
      expect(updated.status, ListStatus.current);
      expect(updated.progress, 5);
      expect(updated.updatedAt, DateTime.utc(2024, 6, 1));
      expect(updated.totalEpisodesOnPage, 24);
    });

    test('copyWith sans argument retourne une copie identique', () {
      final base = ListEntry(
        mediaId: 7,
        status: ListStatus.completed,
        progress: 12,
        hiddenFromPlanning: true,
        updatedAt: dateFixe,
        totalEpisodesOnPage: 12,
      );

      final copy = base.copyWith();

      expect(copy.mediaId, base.mediaId);
      expect(copy.status, base.status);
      expect(copy.progress, base.progress);
      expect(copy.hiddenFromPlanning, base.hiddenFromPlanning);
      expect(copy.updatedAt, base.updatedAt);
      expect(copy.totalEpisodesOnPage, base.totalEpisodesOnPage);
    });

    test('copyWith hiddenFromPlanning', () {
      final base = ListEntry(
        mediaId: 3,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );
      expect(base.copyWith(hiddenFromPlanning: true).hiddenFromPlanning, isTrue);
      expect(base.copyWith(hiddenFromPlanning: false).hiddenFromPlanning, isFalse);
    });
  });

  group('ListEntry valeurs par défaut', () {
    test('progress=0, hiddenFromPlanning=false, totalEpisodesOnPage=0 par défaut', () {
      final entry = ListEntry(
        mediaId: 10,
        status: ListStatus.planning,
        updatedAt: dateFixe,
      );
      expect(entry.progress, 0);
      expect(entry.hiddenFromPlanning, isFalse);
      expect(entry.totalEpisodesOnPage, 0);
    });
  });

  group('ListEntry.calculatedStatus', () {
    test('respecte les statuts manuels gelants indépendamment de la progression', () {
      for (final manual in [ListStatus.paused, ListStatus.dropped, ListStatus.repeating]) {
        final entry = ListEntry(
          mediaId: 1,
          status: manual,
          progress: 12,
          totalEpisodesOnPage: 12,
          updatedAt: dateFixe,
        );
        expect(entry.calculatedStatus, manual);
      }
    });

    test('retourne planning si progress == 0', () {
      final entry = ListEntry(
        mediaId: 1,
        status: ListStatus.planning,
        progress: 0,
        totalEpisodesOnPage: 12,
        updatedAt: dateFixe,
      );
      expect(entry.calculatedStatus, ListStatus.planning);
    });

    test('retourne completed si totalEpisodesOnPage > 0 et progress >= totalEpisodesOnPage', () {
      final entry = ListEntry(
        mediaId: 1,
        status: ListStatus.planning,
        progress: 12,
        totalEpisodesOnPage: 12,
        updatedAt: dateFixe,
      );
      expect(entry.calculatedStatus, ListStatus.completed);

      final overProgress = entry.copyWith(progress: 15);
      expect(overProgress.calculatedStatus, ListStatus.completed);
    });

    test('retourne current si progress < totalEpisodesOnPage', () {
      final entry = ListEntry(
        mediaId: 1,
        status: ListStatus.planning,
        progress: 5,
        totalEpisodesOnPage: 12,
        updatedAt: dateFixe,
      );
      expect(entry.calculatedStatus, ListStatus.current);
    });

    test('retourne current si progress > 0 et totalEpisodesOnPage == 0 (inconnu)', () {
      final entry = ListEntry(
        mediaId: 1,
        status: ListStatus.planning,
        progress: 3,
        totalEpisodesOnPage: 0,
        updatedAt: dateFixe,
      );
      expect(entry.calculatedStatus, ListStatus.current);
    });

    test('rebascule automatiquement un animé complété en current si de nouveaux épisodes sont détectés', () {
      // 1. L'animé est initialement terminé (12/12 épisodes vus)
      final completed = ListEntry(
        mediaId: 1,
        status: ListStatus.completed,
        progress: 12,
        totalEpisodesOnPage: 12,
        updatedAt: dateFixe,
      );
      expect(completed.calculatedStatus, ListStatus.completed);

      // 2. Le scraper détecte un nouvel épisode sur la page (13 épisodes)
      final withNewEpisode = completed.copyWith(totalEpisodesOnPage: 13);
      expect(withNewEpisode.calculatedStatus, ListStatus.current);
    });
  });
}
