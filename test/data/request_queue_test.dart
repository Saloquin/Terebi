import 'dart:async';
import 'package:test/test.dart';
import 'package:terebi/src/data/remote/request_queue.dart';

void main() {
  // Helper : sleep qui ne fait rien (évite toute attente réelle dans les tests).
  Future<void> noSleep(Duration _) async {}

  group('RequestQueue — exécution séquentielle', () {
    test('exécute les tâches dans l\'ordre', () async {
      final order = <int>[];
      final queue = RequestQueue(minDelay: Duration.zero, sleep: noSleep);

      final f1 = queue.add(() async {
        order.add(1);
        return 1;
      });
      final f2 = queue.add(() async {
        order.add(2);
        return 2;
      });
      final f3 = queue.add(() async {
        order.add(3);
        return 3;
      });

      await Future.wait([f1, f2, f3]);

      expect(order, [1, 2, 3]);
    });

    test('retourne la valeur correcte de chaque tâche', () async {
      final queue = RequestQueue(minDelay: Duration.zero, sleep: noSleep);
      final a = queue.add(() async => 'hello');
      final b = queue.add(() async => 42);
      expect(await a, 'hello');
      expect(await b, 42);
    });
  });

  group('RequestQueue — retry sur échec', () {
    test('réessaie et réussit au deuxième essai', () async {
      int attempt = 0;
      final sleepCalls = <Duration>[];

      final queue = RequestQueue(
        maxRetries: 3,
        baseBackoff: const Duration(seconds: 1),
        minDelay: Duration.zero,
        sleep: (d) async => sleepCalls.add(d),
      );

      final result = await queue.add(() async {
        attempt++;
        if (attempt < 2) throw Exception('transient error');
        return 'success';
      });

      expect(result, 'success');
      expect(attempt, 2);
      // Un backoff de 1 s * 2^0 = 1 s doit avoir été demandé.
      expect(sleepCalls, hasLength(1));
      expect(sleepCalls.first, const Duration(seconds: 1));
    });

    test('réessaie et réussit au troisième essai (backoff exponentiel)', () async {
      int attempt = 0;
      final sleepCalls = <Duration>[];

      final queue = RequestQueue(
        maxRetries: 3,
        baseBackoff: const Duration(seconds: 1),
        minDelay: Duration.zero,
        sleep: (d) async => sleepCalls.add(d),
      );

      final result = await queue.add(() async {
        attempt++;
        if (attempt < 3) throw Exception('fail');
        return 'ok';
      });

      expect(result, 'ok');
      expect(attempt, 3);
      // Backoffs : 1 s (2^0), 2 s (2^1).
      expect(sleepCalls.length, 2);
      expect(sleepCalls[0], const Duration(seconds: 1));
      expect(sleepCalls[1], const Duration(seconds: 2));
    });

    test('propage l\'exception après maxRetries tentatives', () async {
      int attempt = 0;
      final queue = RequestQueue(
        maxRetries: 3,
        minDelay: Duration.zero,
        sleep: noSleep,
      );

      await expectLater(
        queue.add(() async {
          attempt++;
          throw Exception('always fails');
        }),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('always fails'),
        )),
      );

      expect(attempt, 3); // 3 tentatives avant abandon
    });

    test('maxRetries=1 : aucun retry (échec immédiat)', () async {
      int attempt = 0;
      final queue = RequestQueue(
        maxRetries: 1,
        minDelay: Duration.zero,
        sleep: noSleep,
      );

      await expectLater(
        queue.add(() async {
          attempt++;
          throw Exception('fail');
        }),
        throwsA(isA<Exception>()),
      );

      expect(attempt, 1);
    });
  });

  group('RequestQueue — tâches indépendantes après erreur', () {
    test('une tâche en erreur n\'empêche pas les suivantes', () async {
      final queue = RequestQueue(
        maxRetries: 1,
        minDelay: Duration.zero,
        sleep: noSleep,
      );

      final f1 = queue.add(() async => throw Exception('boom'));
      final f2 = queue.add(() async => 'second ok');

      await expectLater(f1, throwsA(isA<Exception>()));
      expect(await f2, 'second ok');
    });
  });

  group('RequestQueue — rate limiting (minDelay)', () {
    test('appelle sleep si la requête suivante arrive trop vite', () async {
      final sleepCalls = <Duration>[];
      final queue = RequestQueue(
        maxRetries: 1,
        minDelay: const Duration(milliseconds: 500),
        sleep: (d) async => sleepCalls.add(d),
      );

      // Première tâche : pas de délai précédent.
      await queue.add(() async => 'first');

      // Deuxième tâche : le lastRequestEnd vient d'être posé, elapsed ≈ 0 < 500 ms.
      await queue.add(() async => 'second');

      // Au moins un sleep pour le rate limiting a dû être appelé.
      expect(sleepCalls, isNotEmpty);
    });

    test('pas de sleep si minDelay est zéro', () async {
      final sleepCalls = <Duration>[];
      final queue = RequestQueue(
        maxRetries: 1,
        minDelay: Duration.zero,
        sleep: (d) async => sleepCalls.add(d),
      );

      await queue.add(() async => 'a');
      await queue.add(() async => 'b');

      // Aucun sleep pour le rate limiting (minDelay = 0).
      expect(sleepCalls, isEmpty);
    });
  });
}
