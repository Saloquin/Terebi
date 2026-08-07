/// Repository cache générique — AUCUN import de package:flutter.
///
/// Stocke des payloads texte avec une date d'expiration.
/// Le paramètre [now] est toujours injecté pour la testabilité déterministe.
library;

import 'package:drift/drift.dart';

import '../local/database.dart';

class MetaCacheRepository {
  final TerebiDatabase _db;

  const MetaCacheRepository(this._db);

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Stocke (ou remplace) une entrée de cache.
  Future<void> put(String key, String payload, DateTime expiresAt) async {
    await _db.into(_db.metaCache).insertOnConflictUpdate(
          MetaCacheCompanion.insert(
            cacheKey: key,
            payload: payload,
            expiresAt: expiresAt,
          ),
        );
  }

  /// Retourne le payload si l'entrée existe et n'a pas expiré à [now].
  ///
  /// Retourne `null` si la clé est absente ou expirée.
  Future<String?> get(String key, DateTime now) async {
    final row = await (_db.select(_db.metaCache)
          ..where((t) => t.cacheKey.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    if (row.expiresAt.isBefore(now)) return null;
    return row.payload;
  }

  /// Supprime toutes les entrées expirées à [now].
  Future<void> evictExpired(DateTime now) async {
    await (_db.delete(_db.metaCache)
          ..where((t) => t.expiresAt.isSmallerOrEqualValue(now)))
        .go();
  }

  /// Supprime TOUTES les entrées de cache (bouton « vider le cache »).
  Future<void> clear() async {
    await _db.delete(_db.metaCache).go();
  }
}
