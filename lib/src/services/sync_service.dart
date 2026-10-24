/// Service de synchronisation bidirectionnelle intelligente (Offline-First)
/// entre la base locale SQLite (Drift) et le Cloud Turso (libSQL).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Variable;

import '../data/local/database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/watch_history_repository.dart';
import '../domain/models/episode_progress.dart';
import '../domain/models/list_entry.dart';
import '../domain/models/list_status.dart';
import '../domain/models/user_account.dart';
import '../domain/models/watch_history_entry.dart';

/// États possibles de la synchronisation.
enum SyncState {
  idle,       // Prêt / Inactif
  syncing,    // Synchronisation en cours
  synced,     // Parfaitement à jour avec le Cloud
  offline,    // Hors-ligne (modifications en attente d'envoi)
  error,      // Erreur de communication
}

/// Statut détaillé pour l'affichage dans l'interface (Profil & en-tête).
class SyncStatus {
  final SyncState state;
  final int pendingQueueCount;
  final DateTime? lastSyncedAt;
  final String? message;

  const SyncStatus({
    this.state = SyncState.idle,
    this.pendingQueueCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  SyncStatus copyWith({
    SyncState? state,
    int? pendingQueueCount,
    DateTime? lastSyncedAt,
    String? message,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        pendingQueueCount: pendingQueueCount ?? this.pendingQueueCount,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: message ?? this.message,
      );
}

/// Moteur de synchronisation bidirectionnelle robuste.
class SyncService {
  final TerebiDatabase _db;
  final AuthRepository _authRepo;
  final ListRepository _listRepo;
  final ProgressRepository _progressRepo;
  final WatchHistoryRepository _historyRepo;
  final SettingsRepository _settingsRepo;

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _tableEnsured = false;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = const SyncStatus();

  SyncService({
    required TerebiDatabase db,
    required AuthRepository authRepo,
    required ListRepository listRepo,
    required ProgressRepository progressRepo,
    required WatchHistoryRepository historyRepo,
    required SettingsRepository settingsRepo,
  })  : _db = db,
        _authRepo = authRepo,
        _listRepo = listRepo,
        _progressRepo = progressRepo,
        _historyRepo = historyRepo,
        _settingsRepo = settingsRepo {
    _init();
  }

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _currentStatus;

  void _updateStatus(SyncStatus newStatus) {
    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  Future<void> _init() async {
    await _ensureSyncQueueTable();
    final count = await getPendingQueueCount();
    final lastSyncStr = await _settingsRepo.get('cloud_last_synced_at');
    DateTime? lastSync;
    if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
      lastSync = DateTime.tryParse(lastSyncStr);
    }
    _updateStatus(_currentStatus.copyWith(
      pendingQueueCount: count,
      lastSyncedAt: lastSync,
      state: count > 0 ? SyncState.offline : (lastSync != null ? SyncState.synced : SyncState.idle),
    ));
  }

  /// Initialise la table locale `sync_queue` si elle n'existe pas encore.
  Future<void> _ensureSyncQueueTable() async {
    if (_tableEnsured) return;
    try {
      await _db.customStatement('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          action TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await _db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_sync_queue_user ON sync_queue (user_id);
      ''');
      _tableEnsured = true;
    } catch (_) {}
  }

  /// Nombre de modifications locales en attente d'envoi.
  Future<int> getPendingQueueCount() async {
    await _ensureSyncQueueTable();
    try {
      final rows = await _db.customSelect(
        'SELECT COUNT(*) as cnt FROM sync_queue',
      ).get();
      if (rows.isNotEmpty) {
        return rows.first.data['cnt'] as int? ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ---------------------------------------------------------------------------
  // ENQUEUE ACTIONS (Écritures locales persistées dans la queue)
  // ---------------------------------------------------------------------------

  /// Enregistre une modification d'entrée de bibliothèque dans la file d'attente.
    Future<String> _getEffectiveUserId() async {
    final user = await _getCurrentUser();
    return user?.id ?? 'local';
  }

  /// Enregistre une modification d'entree de bibliotheque dans la file d'attente.
  Future<void> enqueueListEntry(ListEntry entry) async {
    final userId = await _getEffectiveUserId();
    await _ensureSyncQueueTable();

    final payload = jsonEncode(entry.toJson());
    await _coalesceAndEnqueue(
      userId: userId,
      entityType: 'list_entry',
      entityId: entry.mediaId.toString(),
      action: 'upsert',
      payload: payload,
    );
  }

  /// Enregistre la suppression d'une entree de bibliotheque dans la file d'attente.
  Future<void> enqueueListDelete(int mediaId) async {
    final userId = await _getEffectiveUserId();
    await _ensureSyncQueueTable();

    await _coalesceAndEnqueue(
      userId: userId,
      entityType: 'list_entry',
      entityId: mediaId.toString(),
      action: 'delete',
      payload: jsonEncode({'mediaId': mediaId}),
    );
  }

  /// Enregistre une progression d'episode dans la file d'attente.
  Future<void> enqueueEpisodeProgress(EpisodeProgress progress) async {
    final userId = await _getEffectiveUserId();
    await _ensureSyncQueueTable();

    final payload = jsonEncode(progress.toJson());
    await _coalesceAndEnqueue(
      userId: userId,
      entityType: 'episode_progress',
      entityId: '${progress.mediaId}:${progress.episodeNumber}',
      action: 'upsert',
      payload: payload,
    );
  }

  /// Enregistre un historique de visionnage dans la file d'attente.
  Future<void> enqueueWatchHistory(WatchHistoryEntry history) async {
    final userId = await _getEffectiveUserId();
    await _ensureSyncQueueTable();

    final payload = jsonEncode(history.toJson());
    await _coalesceAndEnqueue(
      userId: userId,
      entityType: 'watch_history',
      entityId: '${history.mediaId}:${history.episodeNumber}:${history.startedAt.millisecondsSinceEpoch}',
      action: 'upsert',
      payload: payload,
    );
  }

  Future<void> _coalesceAndEnqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required String action,
    required String payload,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement('''
        DELETE FROM sync_queue WHERE user_id = ? AND entity_type = ? AND entity_id = ?;
      ''', [userId, entityType, entityId]);

      await _db.customStatement('''
        INSERT INTO sync_queue (user_id, entity_type, entity_id, action, payload, created_at)
        VALUES (?, ?, ?, ?, ?, ?);
      ''', [userId, entityType, entityId, action, payload, now]);

      final count = await getPendingQueueCount();
      _updateStatus(_currentStatus.copyWith(
        pendingQueueCount: count,
        state: SyncState.offline,
      ));

      _scheduleDebouncedFlush();
    } catch (_) {}
  }

  void _scheduleDebouncedFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      flushQueue();
    });
  }

  Future<UserAccount?> _getCurrentUser() async {
    return _authRepo.restoreSession();
  }

  // ---------------------------------------------------------------------------
  // FLUSH QUEUE (Envoi des modifications locales vers Turso)
  // ---------------------------------------------------------------------------

  /// Vide la file d'attente vers Turso par lots en pipeline HTTP.
  Future<bool> flushQueue() async {
    if (_isSyncing) return false;
    final user = await _getCurrentUser();
    if (user == null) return false;

    await _ensureSyncQueueTable();
    try {
      await _db.customStatement(
        'UPDATE sync_queue SET user_id = ? WHERE user_id = "local"',
        [user.id],
      );
    } catch (_) {}
    final rows = await _db.customSelect(
      'SELECT * FROM sync_queue WHERE user_id = ? ORDER BY id ASC LIMIT 100',
      variables: [Variable.withString(user.id)],
    ).get();

    if (rows.isEmpty) {
      final count = await getPendingQueueCount();
      _updateStatus(_currentStatus.copyWith(
        pendingQueueCount: count,
        state: count == 0 ? SyncState.synced : SyncState.offline,
      ));
      return true;
    }

    _isSyncing = true;
    _updateStatus(_currentStatus.copyWith(state: SyncState.syncing));

    try {
      final statements = <({String sql, List<dynamic>? args})>[];
      final processedIds = <int>[];

      for (final r in rows) {
        final id = r.data['id'] as int;
        final entityType = r.data['entity_type'] as String;
        final action = r.data['action'] as String;
        final payload = jsonDecode(r.data['payload'] as String) as Map<String, dynamic>;

        if (entityType == 'list_entry') {
          if (action == 'upsert') {
            final entry = ListEntry.fromJson(payload);
            statements.add((
              sql: '''
                INSERT INTO list_entries (user_id, media_id, status, progress, hidden_from_planning, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id, media_id) DO UPDATE SET
                  status = excluded.status,
                  progress = excluded.progress,
                  hidden_from_planning = excluded.hidden_from_planning,
                  updated_at = excluded.updated_at
              ''',
              args: [
                user.id,
                entry.mediaId,
                entry.status.name,
                entry.progress,
                entry.hiddenFromPlanning ? 1 : 0,
                entry.updatedAt.millisecondsSinceEpoch,
              ],
            ));
          } else if (action == 'delete') {
            final mediaId = payload['mediaId'] as int;
            statements.add((
              sql: 'DELETE FROM list_entries WHERE user_id = ? AND media_id = ?',
              args: [user.id, mediaId],
            ));
          }
        } else if (entityType == 'episode_progress') {
          final p = EpisodeProgress.fromJson(payload);
          statements.add((
            sql: '''
              INSERT INTO episode_progresses (user_id, media_id, episode_number, watched, position_seconds, duration_seconds, completed_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(user_id, media_id, episode_number) DO UPDATE SET
                watched = excluded.watched,
                position_seconds = excluded.position_seconds,
                duration_seconds = excluded.duration_seconds,
                completed_at = excluded.completed_at,
                updated_at = excluded.updated_at
            ''',
            args: [
              user.id,
              p.mediaId,
              p.episodeNumber,
              p.watched ? 1 : 0,
              p.positionSeconds,
              p.durationSeconds,
              p.completedAt?.millisecondsSinceEpoch,
              p.updatedAt.millisecondsSinceEpoch,
            ],
          ));
        } else if (entityType == 'watch_history') {
          final h = WatchHistoryEntry.fromJson(payload);
          statements.add((
            sql: '''
              INSERT INTO watch_histories (user_id, media_id, episode_number, started_at, ended_at, watched_seconds)
              VALUES (?, ?, ?, ?, NULL, 0.0)
            ''',
            args: [
              user.id,
              h.mediaId,
              h.episodeNumber,
              h.startedAt.millisecondsSinceEpoch,
            ],
          ));
        }

        processedIds.add(id);
      }

      if (statements.isNotEmpty) {
        await _authRepo.client.batch(statements);
      }

      // Suppression des requêtes traitées avec succès
      final idPlaceholders = List.filled(processedIds.length, '?').join(',');
      await _db.customStatement(
        'DELETE FROM sync_queue WHERE id IN ($idPlaceholders)',
        processedIds,
      );

      final remaining = await getPendingQueueCount();
      final now = DateTime.now();
      await _settingsRepo.set('cloud_last_synced_at', now.toIso8601String());

      _isSyncing = false;
      _updateStatus(_currentStatus.copyWith(
        pendingQueueCount: remaining,
        lastSyncedAt: now,
        state: remaining > 0 ? SyncState.offline : SyncState.synced,
      ));

      if (remaining > 0) {
        // Enchaîne avec le lot suivant
        scheduleMicrotask(flushQueue);
      }
      return true;
    } catch (e) {
      _isSyncing = false;
      final remaining = await getPendingQueueCount();
      _updateStatus(_currentStatus.copyWith(
        pendingQueueCount: remaining,
        state: SyncState.offline,
        message: 'Connexion indisponible. Enregistré localement.',
      ));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FULL BIDIRECTIONAL SYNC (Diff intelligent sans perte de données)
  // ---------------------------------------------------------------------------

  /// Exécute une réconciliation bidirectionnelle complète :
  /// 1. Vide d'abord la queue locale (envoie nos actions hors-ligne).
  /// 2. Télécharge l'état de Turso pour ce compte.
  /// 3. Compare ligne par ligne avec la base locale (règle monotone pour les épisodes,
  ///    règle de date pour les listes, union pour l'historique).
  /// 4. Met à jour le Cloud et le local sans jamais régresser.
  Future<bool> fullSync() async {
    if (_isSyncing) return false;
    final user = await _getCurrentUser();
    if (user == null) return false;

    _isSyncing = true;
    _updateStatus(_currentStatus.copyWith(state: SyncState.syncing));

    try {
      // 1. Draine d'abord les deltas locaux
      await flushQueue();

      final client = _authRepo.client;

      // 2. Récupère les données Cloud de l'utilisateur
      final remoteListRows = await client.query(
        'SELECT * FROM list_entries WHERE user_id = ?',
        [user.id],
      );
      final remoteProgressRows = await client.query(
        'SELECT * FROM episode_progresses WHERE user_id = ?',
        [user.id],
      );
      final remoteHistoryRows = await client.query(
        'SELECT * FROM watch_histories WHERE user_id = ?',
        [user.id],
      );

      // 3. Récupère les données locales
      final localEntries = await _listRepo.getAllEntries();
      final localProgresses = await _progressRepo.getAllProgresses();
      final localHistories = await _historyRepo.all();

      final statementsToPush = <({String sql, List<dynamic>? args})>[];

      // -----------------------------------------------------------------------
      // A. DIFF SUR LES ENTRÉES DE LISTE (Last-Write-Wins + Max Progress)
      // -----------------------------------------------------------------------
      final localEntryMap = {for (final e in localEntries) e.mediaId: e};
      final remoteEntryMap = <int, Map<String, dynamic>>{};
      for (final r in remoteListRows) {
        final mid = r['media_id'] as int;
        remoteEntryMap[mid] = r;
      }

      final allMediaIds = {...localEntryMap.keys, ...remoteEntryMap.keys};

      for (final mid in allMediaIds) {
        final local = localEntryMap[mid];
        final remote = remoteEntryMap[mid];

        if (local != null && remote == null) {
          // Présent en local, absent du Cloud -> Push vers Turso
          statementsToPush.add((
            sql: '''
              INSERT INTO list_entries (user_id, media_id, status, progress, hidden_from_planning, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)
            ''',
            args: [
              user.id,
              local.mediaId,
              local.status.name,
              local.progress,
              local.hiddenFromPlanning ? 1 : 0,
              local.updatedAt.millisecondsSinceEpoch,
            ],
          ));
        } else if (local == null && remote != null) {
          // Présent sur le Cloud, absent en local -> Pull dans SQLite
          final statusStr = remote['status']?.toString() ?? 'planning';
          final st = ListStatus.values.byName(statusStr);
          final progress = remote['progress'] as int? ?? 0;
          final hidden = (remote['hidden_from_planning'] == 1 || remote['hidden_from_planning'] == true);
          final updatedMs = remote['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch;

          await _listRepo.upsertEntry(
            ListEntry(
              mediaId: mid,
              status: st,
              progress: progress,
              hiddenFromPlanning: hidden,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
            ),
            notifySync: false,
          );
        } else if (local != null && remote != null) {
          // Présent des deux côtés -> Comparaison de dates et progression maximale
          final localMs = local.updatedAt.millisecondsSinceEpoch;
          final remoteMs = remote['updated_at'] as int? ?? 0;
          final remoteProgress = remote['progress'] as int? ?? 0;

          if (localMs > remoteMs + 2000) {
            // Local plus récent -> Push vers Turso
            statementsToPush.add((
              sql: '''
                UPDATE list_entries SET
                  status = ?, progress = ?, hidden_from_planning = ?, updated_at = ?
                WHERE user_id = ? AND media_id = ?
              ''',
              args: [
                local.status.name,
                local.progress,
                local.hiddenFromPlanning ? 1 : 0,
                local.updatedAt.millisecondsSinceEpoch,
                user.id,
                mid,
              ],
            ));
          } else if (remoteMs > localMs + 2000) {
            // Cloud plus récent -> Pull dans SQLite
            final statusStr = remote['status']?.toString() ?? local.status.name;
            final st = ListStatus.values.byName(statusStr);
            final hidden = (remote['hidden_from_planning'] == 1 || remote['hidden_from_planning'] == true);

            await _listRepo.upsertEntry(
              local.copyWith(
                status: st,
                progress: max(local.progress, remoteProgress),
                hiddenFromPlanning: hidden,
                updatedAt: DateTime.fromMillisecondsSinceEpoch(remoteMs),
              ),
              notifySync: false,
            );
          } else if (local.progress != remoteProgress) {
            // Dates équivalentes mais progression différente -> Toujours garder le maximum
            final maxProg = max(local.progress, remoteProgress);
            if (local.progress < maxProg) {
              await _listRepo.upsertEntry(
                local.copyWith(progress: maxProg),
                notifySync: false,
              );
            } else {
              statementsToPush.add((
                sql: 'UPDATE list_entries SET progress = ? WHERE user_id = ? AND media_id = ?',
                args: [maxProg, user.id, mid],
              ));
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // B. DIFF SUR LES PROGRESSIONS D'ÉPISODES (Règle Monotone + Complétion)
      // -----------------------------------------------------------------------
      final localProgressMap = {
        for (final p in localProgresses) '${p.mediaId}:${p.episodeNumber}': p
      };
      final remoteProgressMap = <String, Map<String, dynamic>>{};
      for (final r in remoteProgressRows) {
        final mid = r['media_id'];
        final ep = (r['episode_number'] as num).toDouble();
        remoteProgressMap['$mid:$ep'] = r;
      }

      final allEpKeys = {...localProgressMap.keys, ...remoteProgressMap.keys};

      for (final key in allEpKeys) {
        final local = localProgressMap[key];
        final remote = remoteProgressMap[key];

        if (local != null && remote == null) {
          // Présent en local uniquement -> Push
          statementsToPush.add((
            sql: '''
              INSERT INTO episode_progresses (user_id, media_id, episode_number, watched, position_seconds, duration_seconds, completed_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            args: [
              user.id,
              local.mediaId,
              local.episodeNumber,
              local.watched ? 1 : 0,
              local.positionSeconds,
              local.durationSeconds,
              local.completedAt?.millisecondsSinceEpoch,
              local.updatedAt.millisecondsSinceEpoch,
            ],
          ));
        } else if (local == null && remote != null) {
          // Présent sur le Cloud uniquement -> Pull
          final mid = remote['media_id'] as int;
          final ep = (remote['episode_number'] as num).toDouble();
          final watched = (remote['watched'] == 1 || remote['watched'] == true);
          final pos = (remote['position_seconds'] as num?)?.toDouble() ?? 0.0;
          final dur = (remote['duration_seconds'] as num?)?.toDouble();
          final compMs = remote['completed_at'] as int?;
          final updatedMs = remote['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch;

          await _progressRepo.upsertProgress(
            EpisodeProgress(
              mediaId: mid,
              episodeNumber: ep,
              watched: watched,
              positionSeconds: pos,
              durationSeconds: dur,
              completedAt: compMs != null ? DateTime.fromMillisecondsSinceEpoch(compMs) : null,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
            ),
            notifySync: false,
          );
        } else if (local != null && remote != null) {
          // Présent des deux côtés : application de la règle monotone
          final localWatched = local.watched;
          final remoteWatched = (remote['watched'] == 1 || remote['watched'] == true);
          final localPos = local.positionSeconds;
          final remotePos = (remote['position_seconds'] as num?)?.toDouble() ?? 0.0;
          final remoteUpdatedMs = remote['updated_at'] as int? ?? 0;
          final localUpdatedMs = local.updatedAt.millisecondsSinceEpoch;

          if (remoteWatched && !localWatched) {
            // Le cloud a terminé l'épisode -> Local devient terminé !
            await _progressRepo.upsertProgress(
              EpisodeProgress(
                mediaId: local.mediaId,
                episodeNumber: local.episodeNumber,
                watched: true,
                positionSeconds: max(localPos, remotePos),
                durationSeconds: local.durationSeconds ?? (remote['duration_seconds'] as num?)?.toDouble(),
                completedAt: local.completedAt ?? DateTime.fromMillisecondsSinceEpoch(remoteUpdatedMs),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(max(localUpdatedMs, remoteUpdatedMs)),
              ),
              notifySync: false,
            );
          } else if (localWatched && !remoteWatched) {
            // Le local a terminé l'épisode -> Le cloud devient terminé !
            statementsToPush.add((
              sql: '''
                UPDATE episode_progresses SET
                  watched = 1, position_seconds = ?, updated_at = ?
                WHERE user_id = ? AND media_id = ? AND episode_number = ?
              ''',
              args: [
                max(localPos, remotePos),
                local.updatedAt.millisecondsSinceEpoch,
                user.id,
                local.mediaId,
                local.episodeNumber,
              ],
            ));
          } else {
            // Mêmes statuts de complétion : on compare la position dans l'épisode
            if (remotePos > localPos + 5.0) {
              // Le visionnage Cloud est plus avancé -> Pull
              await _progressRepo.upsertProgress(
                EpisodeProgress(
                  mediaId: local.mediaId,
                  episodeNumber: local.episodeNumber,
                  watched: localWatched,
                  positionSeconds: remotePos,
                  durationSeconds: local.durationSeconds ?? (remote['duration_seconds'] as num?)?.toDouble(),
                  completedAt: local.completedAt,
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(max(localUpdatedMs, remoteUpdatedMs)),
                ),
                notifySync: false,
              );
            } else if (localPos > remotePos + 5.0) {
              // Le visionnage Local est plus avancé -> Push
              statementsToPush.add((
                sql: '''
                  UPDATE episode_progresses SET
                    position_seconds = ?, updated_at = ?
                  WHERE user_id = ? AND media_id = ? AND episode_number = ?
                ''',
                args: [
                  localPos,
                  local.updatedAt.millisecondsSinceEpoch,
                  user.id,
                  local.mediaId,
                  local.episodeNumber,
                ],
              ));
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // C. DIFF SUR L'HISTORIQUE (Union additive stricte sans suppression)
      // -----------------------------------------------------------------------
      final localHistKeys = {
        for (final h in localHistories) '${h.mediaId}:${h.episodeNumber}:${h.startedAt.millisecondsSinceEpoch}'
      };
      final remoteHistKeys = <String>{};

      for (final r in remoteHistoryRows) {
        final mid = r['media_id'];
        final ep = (r['episode_number'] as num).toDouble();
        final started = r['started_at'] as int;
        final key = '$mid:$ep:$started';
        remoteHistKeys.add(key);

        if (!localHistKeys.contains(key)) {
          // Historique présent sur le Cloud mais manquant en local -> insertion locale
          await _historyRepo.record(
            mediaId: mid as int,
            episodeNumber: ep,
            startedAt: DateTime.fromMillisecondsSinceEpoch(started),
            notifySync: false,
          );
        }
      }

      for (final h in localHistories) {
        final key = '${h.mediaId}:${h.episodeNumber}:${h.startedAt.millisecondsSinceEpoch}';
        if (!remoteHistKeys.contains(key)) {
          // Historique local manquant sur le Cloud -> insertion Cloud
          statementsToPush.add((
            sql: '''
              INSERT INTO watch_histories (user_id, media_id, episode_number, started_at, ended_at, watched_seconds)
              VALUES (?, ?, ?, ?, NULL, 0.0)
            ''',
            args: [
              user.id,
              h.mediaId,
              h.episodeNumber,
              h.startedAt.millisecondsSinceEpoch,
            ],
          ));
        }
      }

      // Envoi groupé des mises à jour vers Turso
      if (statementsToPush.isNotEmpty) {
        await client.batch(statementsToPush);
      }

      final now = DateTime.now();
      await _settingsRepo.set('cloud_last_synced_at', now.toIso8601String());

      _isSyncing = false;
      _updateStatus(_currentStatus.copyWith(
        pendingQueueCount: 0,
        lastSyncedAt: now,
        state: SyncState.synced,
        message: 'Synchronisation terminée avec succès.',
      ));
      return true;
    } catch (e) {
      _isSyncing = false;
      _updateStatus(_currentStatus.copyWith(
        state: SyncState.error,
        message: 'Erreur lors de la synchronisation : $e',
      ));
      return false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _statusController.close();
  }
}
