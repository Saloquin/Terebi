/// Domaine pur — AUCUN import de package:flutter (testable via `dart test`).
///
/// Sélection aléatoire d'une entrée dans un onglet de bibliothèque (En cours /
/// Planifié) en évitant si possible de retomber deux fois de suite sur la même.
library;

import 'dart:math';

import '../models/list_entry.dart';

/// Retourne une copie mélangée de [entries]. Si [excludeMediaId] est fourni et
/// qu'au moins deux entrées distinctes existent, garantit que le premier
/// élément n'a pas `mediaId == excludeMediaId`.
List<ListEntry> shuffledEntriesForRandomPick(
  List<ListEntry> entries, {
  int? excludeMediaId,
  Random? random,
}) {
  if (entries.isEmpty) return const [];
  final rng = random ?? Random();
  final pool = List<ListEntry>.from(entries)..shuffle(rng);

  if (excludeMediaId != null &&
      pool.length > 1 &&
      pool.first.mediaId == excludeMediaId) {
    final altIdx = pool.indexWhere((e) => e.mediaId != excludeMediaId);
    if (altIdx > 0) {
      final first = pool[0];
      pool[0] = pool[altIdx];
      pool[altIdx] = first;
    }
  }
  return pool;
}
