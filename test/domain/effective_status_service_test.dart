import 'package:test/test.dart';
import 'package:terebi/src/domain/logic/effective_status_service.dart';
import 'package:terebi/src/domain/models/list_entry.dart';
import 'package:terebi/src/domain/models/list_status.dart';

void main() {
  ListEntry entry(ListStatus status, {int progress = 0}) => ListEntry(
        mediaId: 1,
        status: status,
        progress: progress,
        updatedAt: DateTime.utc(2020),
      );

  group('effectiveStatus', () {
    test('null + aucune progression → null (hors listes)', () {
      expect(effectiveStatus(entry: null, hasProgress: false), isNull);
    });

    test('null + progression → En cours (calculé)', () {
      expect(effectiveStatus(entry: null, hasProgress: true),
          ListStatus.current);
    });

    test('completed stocké → Terminé (drapeau, prioritaire)', () {
      expect(
        effectiveStatus(
            entry: entry(ListStatus.completed, progress: 12),
            hasProgress: true),
        ListStatus.completed,
      );
    });

    test('planning + aucune progression → Planifié', () {
      expect(
        effectiveStatus(entry: entry(ListStatus.planning), hasProgress: false),
        ListStatus.planning,
      );
    });

    test('planning + progression → En cours (planning ne gèle pas)', () {
      expect(
        effectiveStatus(
            entry: entry(ListStatus.planning, progress: 3), hasProgress: true),
        ListStatus.current,
      );
    });

    test('paused gèle même avec progression → reste En pause', () {
      expect(
        effectiveStatus(
            entry: entry(ListStatus.paused, progress: 3), hasProgress: true),
        ListStatus.paused,
      );
    });

    test('dropped gèle même avec progression → reste Abandonné', () {
      expect(
        effectiveStatus(
            entry: entry(ListStatus.dropped, progress: 5), hasProgress: true),
        ListStatus.dropped,
      );
    });

    test('repeating gèle → reste Revisionnage', () {
      expect(
        effectiveStatus(
            entry: entry(ListStatus.repeating, progress: 5),
            hasProgress: true),
        ListStatus.repeating,
      );
    });
  });

  group('isFreezingManualStatus', () {
    test('paused/dropped/repeating gèlent', () {
      expect(isFreezingManualStatus(ListStatus.paused), isTrue);
      expect(isFreezingManualStatus(ListStatus.dropped), isTrue);
      expect(isFreezingManualStatus(ListStatus.repeating), isTrue);
    });
    test('planning/current/completed ne gèlent pas', () {
      expect(isFreezingManualStatus(ListStatus.planning), isFalse);
      expect(isFreezingManualStatus(ListStatus.current), isFalse);
      expect(isFreezingManualStatus(ListStatus.completed), isFalse);
    });
  });

  group('kManualStatuses', () {
    test('ne contient QUE les 4 statuts manuels', () {
      expect(kManualStatuses, [
        ListStatus.planning,
        ListStatus.paused,
        ListStatus.dropped,
        ListStatus.repeating,
      ]);
      expect(kManualStatuses.contains(ListStatus.current), isFalse);
      expect(kManualStatuses.contains(ListStatus.completed), isFalse);
    });
  });
}
