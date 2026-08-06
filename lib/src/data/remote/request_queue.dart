/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// File de requêtes résiliente avec limitation de débit, retry et backoff
/// exponentiel (US-115).
library;

import 'dart:async';

/// Signature d'une fonction de délai injectable (pour les tests).
typedef SleepFn = Future<void> Function(Duration);

/// File de requêtes qui sérialise l'exécution de tâches asynchrones,
/// avec retry automatique et backoff exponentiel.
///
/// **Utilisation** :
/// ```dart
/// final queue = RequestQueue();
/// final result = await queue.add(() => myApiCall());
/// ```
///
/// **Tests** : injectez [sleep] pour éviter toute attente réelle :
/// ```dart
/// final queue = RequestQueue(sleep: (_) async {});
/// ```
class RequestQueue {
  /// Nombre maximum de tentatives par tâche (1 = aucun retry).
  final int maxRetries;

  /// Délai minimum entre deux requêtes successives (respect du débit API).
  final Duration minDelay;

  /// Délai de base pour le backoff exponentiel.
  final Duration baseBackoff;

  /// Fonction de délai injectable (défaut : [Future.delayed]).
  final SleepFn sleep;

  /// Heure de fin de la dernière requête exécutée (pour le rate-limiting).
  DateTime? _lastRequestEnd;

  /// Verrou léger : les tâches se chaînent sur cette future.
  Future<void> _chain = Future.value();

  RequestQueue({
    this.maxRetries = 3,
    this.minDelay = const Duration(milliseconds: 700),
    this.baseBackoff = const Duration(seconds: 1),
    SleepFn? sleep,
  }) : sleep = sleep ?? ((d) => Future<void>.delayed(d));

  /// Ajoute une tâche [task] dans la file et retourne son résultat.
  ///
  /// La tâche est exécutée après toutes les tâches précédemment ajoutées.
  /// En cas d'échec réseau ou HTTP 429, elle est réessayée jusqu'à
  /// [maxRetries] fois avec un backoff exponentiel.
  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();

    _chain = _chain.then((_) => _runWithRetry(task, completer));

    return completer.future;
  }

  Future<void> _runWithRetry<T>(
    Future<T> Function() task,
    Completer<T> completer,
  ) async {
    // Respect du délai minimum entre requêtes (rate-limiting).
    final now = DateTime.now();
    if (_lastRequestEnd != null) {
      final elapsed = now.difference(_lastRequestEnd!);
      if (elapsed < minDelay) {
        await sleep(minDelay - elapsed);
      }
    }

    int attempt = 0;
    while (true) {
      try {
        final result = await task();
        _lastRequestEnd = DateTime.now();
        completer.complete(result);
        return;
      } catch (e, st) {
        _lastRequestEnd = DateTime.now();
        attempt++;
        if (attempt >= maxRetries) {
          completer.completeError(e, st);
          return;
        }
        // Backoff exponentiel : baseBackoff * 2^(attempt-1)
        final backoff = baseBackoff * (1 << (attempt - 1));
        await sleep(backoff);
      }
    }
  }
}
