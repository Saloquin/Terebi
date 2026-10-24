/// Dépôt d'authentification et gestion de profil connecté avec Turso.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/leaderboard_entry.dart';
import '../../domain/models/user_account.dart';
import '../remote/turso_client.dart';
import 'settings_repository.dart';

/// Configuration par défaut de la base de données Turso Terebi.
const defaultTursoUrl = 'https://terebi-saloquin.aws-eu-west-1.turso.io';
const defaultTursoToken =
    'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3OTI4NzY4MTYsImlkIjoiMDFhMTZmYzktMGQwMS03ZDNjLThiNWEtYjQxZTA3OGYyYzY4Iiwia2lkIjoiTXRPeDVrUHRWOVRqZEpQMDNyUXZGRklCaENydnB4LUs3MG5rUFVzQjlUdyIsInJpZCI6IjAyYmUyYzBkLWViZDctNDRjMS04ZjI4LWZkNGQ5MjQzMTY2NCJ9.uXLu6xYQmxVb3xtYr86njwTat0r9Oeedn2Vp1vY1QTzSndk4EzpyBdBB6ikYMHcNeJGCC3AqC1VyELXBgMikCA';

class UserProfileStats {
  final int totalEntries;
  final int completedCount;
  final int currentCount;
  final int planningCount;
  final int watchedEpisodesCount;
  final double totalWatchedHours;

  const UserProfileStats({
    this.totalEntries = 0,
    this.completedCount = 0,
    this.currentCount = 0,
    this.planningCount = 0,
    this.watchedEpisodesCount = 0,
    this.totalWatchedHours = 0.0,
  });
}

class AuthRepository {
  final SettingsRepository _settings;
  TursoClient _client;

  AuthRepository(this._settings, {TursoClient? client})
      : _client = client ?? TursoClient(url: defaultTursoUrl, token: defaultTursoToken);

  /// Met à jour le client Turso si l'utilisateur change son URL/token dans les paramètres.
  void updateTursoConfig({required String url, required String token}) {
    _client.close();
    _client = TursoClient(url: url, token: token);
  }

  static String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode(salt + password)).toString();
  }

  static String _generateRandomHex(int bytesCount) {
    final rand = Random.secure();
    final bytes = List<int>.generate(bytesCount, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Tente de restaurer la session sauvegardée ("Rester connecté").
  Future<UserAccount?> restoreSession() async {
    final token = await _settings.get('auth_session_token');
    if (token == null || token.isEmpty) return null;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = await _client.query('''
        SELECT u.* FROM users u
        JOIN user_sessions s ON s.user_id = u.id
        WHERE s.token = ? AND (s.expires_at IS NULL OR s.expires_at > ?)
        LIMIT 1
      ''', [token, now]);

      if (rows.isEmpty) {
        // Session invalide ou expirée en ligne
        await _settings.delete('auth_session_token');
        await _settings.delete('auth_user_id');
        return null;
      }

      // Met à jour la dernière utilisation
      await _client.execute(
        'UPDATE user_sessions SET last_used_at = ? WHERE token = ?',
        [now, token],
      );

      return UserAccount.fromMap(rows.first);
    } catch (_) {
      // En cas d'absence de réseau au démarrage, on peut tenter de charger
      // le profil mémorisé localement si disponible.
      final cachedJson = await _settings.get('auth_cached_user');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          return UserAccount.fromMap(jsonDecode(cachedJson));
        } catch (_) {}
      }
      return null;
    }
  }

  /// Connexion par pseudo et mot de passe.
  Future<UserAccount> login(String username, String password) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw const TursoException('Veuillez renseigner un pseudo.');
    }
    if (password.isEmpty) {
      throw const TursoException('Veuillez renseigner votre mot de passe.');
    }

    final rows = await _client.query(
      'SELECT * FROM users WHERE username = ? COLLATE NOCASE LIMIT 1',
      [cleanUsername],
    );

    if (rows.isEmpty) {
      throw const TursoException('Compte introuvable pour ce pseudo.');
    }

    final userRow = rows.first;
    final salt = userRow['salt']?.toString() ?? '';
    final storedHash = userRow['password_hash']?.toString() ?? '';
    final computedHash = _hashPassword(password, salt);

    if (computedHash != storedHash) {
      throw const TursoException('Mot de passe incorrect.');
    }

    final user = UserAccount.fromMap(userRow);

    // Création d'un token de session persistante ("Rester connecté")
    final sessionToken = _generateRandomHex(32);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _client.execute('''
      INSERT INTO user_sessions (token, user_id, device_name, created_at, last_used_at, expires_at)
      VALUES (?, ?, ?, ?, ?, NULL)
    ''', [sessionToken, user.id, 'Terebi App', now, now]);

    // Stockage local
    await _settings.set('auth_session_token', sessionToken);
    await _settings.set('auth_user_id', user.id);
    await _settings.set('auth_cached_user', jsonEncode(user.toMap()));

    return user;
  }

  /// Inscription d'un nouvel utilisateur.
  Future<UserAccount> register({
    required String username,
    required String password,
    String? email,
    String avatarStyle = 'lorelei',
    String? avatarSeed,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.length < 2) {
      throw const TursoException('Le pseudo doit contenir au moins 2 caractères.');
    }
    if (password.length < 4) {
      throw const TursoException('Le mot de passe doit contenir au moins 4 caractères.');
    }

    // Vérifie si le pseudo est déjà pris
    final existing = await _client.query(
      'SELECT id FROM users WHERE username = ? COLLATE NOCASE LIMIT 1',
      [cleanUsername],
    );
    if (existing.isNotEmpty) {
      throw const TursoException('Ce pseudo est déjà pris. Veuillez en choisir un autre.');
    }

    final userId = _generateRandomHex(16);
    final salt = _generateRandomHex(16);
    final pwdHash = _hashPassword(password, salt);
    final seed = (avatarSeed != null && avatarSeed.trim().isNotEmpty)
        ? avatarSeed.trim()
        : cleanUsername;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _client.execute('''
      INSERT INTO users (id, username, email, password_hash, salt, avatar_style, avatar_seed, bio, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      userId,
      cleanUsername,
      email?.trim().isNotEmpty == true ? email!.trim() : null,
      pwdHash,
      salt,
      avatarStyle,
      seed,
      'Nouveau membre Terebi',
      now,
      now,
    ]);

    // Connexion immédiate
    final sessionToken = _generateRandomHex(32);
    await _client.execute('''
      INSERT INTO user_sessions (token, user_id, device_name, created_at, last_used_at, expires_at)
      VALUES (?, ?, ?, ?, ?, NULL)
    ''', [sessionToken, userId, 'Terebi App', now, now]);

    final user = UserAccount(
      id: userId,
      username: cleanUsername,
      email: email?.trim(),
      avatarStyle: avatarStyle,
      avatarSeed: seed,
      bio: 'Nouveau membre Terebi',
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );

    await _settings.set('auth_session_token', sessionToken);
    await _settings.set('auth_user_id', user.id);
    await _settings.set('auth_cached_user', jsonEncode(user.toMap()));

    return user;
  }

  /// Déconnexion du compte actif.
  Future<void> logout() async {
    final token = await _settings.get('auth_session_token');
    if (token != null && token.isNotEmpty) {
      try {
        await _client.execute('DELETE FROM user_sessions WHERE token = ?', [token]);
      } catch (_) {}
    }
    await _settings.delete('auth_session_token');
    await _settings.delete('auth_user_id');
    await _settings.delete('auth_cached_user');
  }

  /// Mise à jour du profil (pseudo, style/graine DiceBear ou bio).
  Future<UserAccount> updateProfile(
    UserAccount currentUser, {
    String? username,
    String? avatarStyle,
    String? avatarSeed,
    String? bio,
  }) async {
    String newUsername = currentUser.username;
    if (username != null && username.trim().isNotEmpty && username.trim() != currentUser.username) {
      final clean = username.trim();
      if (clean.length < 2) {
        throw const TursoException('Le pseudo doit comporter au moins 2 caractères.');
      }
      final existing = await _client.query(
        'SELECT id FROM users WHERE username = ? COLLATE NOCASE AND id != ? LIMIT 1',
        [clean, currentUser.id],
      );
      if (existing.isNotEmpty) {
        throw const TursoException('Ce pseudo est déjà pris.');
      }
      newUsername = clean;
    }

    final newStyle = avatarStyle ?? currentUser.avatarStyle;
    final newSeed = avatarSeed ?? currentUser.avatarSeed;
    final newBio = bio ?? currentUser.bio;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _client.execute('''
      UPDATE users 
      SET username = ?, avatar_style = ?, avatar_seed = ?, bio = ?, updated_at = ?
      WHERE id = ?
    ''', [newUsername, newStyle, newSeed, newBio, now, currentUser.id]);

    final updated = currentUser.copyWith(
      username: newUsername,
      avatarStyle: newStyle,
      avatarSeed: newSeed,
      bio: newBio,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );

    await _settings.set('auth_cached_user', jsonEncode(updated.toMap()));
    return updated;
  }

  /// Modification du mot de passe.
  Future<void> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 4) {
      throw const TursoException('Le nouveau mot de passe doit faire au moins 4 caractères.');
    }

    final rows = await _client.query(
      'SELECT salt, password_hash FROM users WHERE id = ? LIMIT 1',
      [userId],
    );
    if (rows.isEmpty) throw const TursoException('Utilisateur introuvable.');

    final salt = rows.first['salt']?.toString() ?? '';
    final storedHash = rows.first['password_hash']?.toString() ?? '';
    if (_hashPassword(oldPassword, salt) != storedHash) {
      throw const TursoException('L\'ancien mot de passe est incorrect.');
    }

    final newSalt = _generateRandomHex(16);
    final newHash = _hashPassword(newPassword, newSalt);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _client.execute('''
      UPDATE users SET password_hash = ?, salt = ?, updated_at = ? WHERE id = ?
    ''', [newHash, newSalt, now, userId]);
  }

  /// Récupère les statistiques de l'utilisateur (animes, épisodes, temps).
  Future<UserProfileStats> getUserStats(String userId) async {
    try {
      final entriesRows = await _client.query('''
        SELECT status, COUNT(*) as count 
        FROM list_entries 
        WHERE user_id = ? 
        GROUP BY status
      ''', [userId]);

      int total = 0;
      int completed = 0;
      int current = 0;
      int planning = 0;

      for (final r in entriesRows) {
        final st = r['status']?.toString();
        final c = (r['count'] is int) ? r['count'] as int : int.tryParse(r['count']?.toString() ?? '') ?? 0;
        total += c;
        if (st == 'completed') completed = c;
        if (st == 'current') current = c;
        if (st == 'planning') planning = c;
      }

      final epRows = await _client.query('''
        SELECT COUNT(*) as count 
        FROM episode_progresses 
        WHERE user_id = ? AND watched = 1
      ''', [userId]);
      final watchedEps = epRows.isNotEmpty ? (epRows.first['count'] is int ? epRows.first['count'] as int : int.tryParse(epRows.first['count']?.toString() ?? '') ?? 0) : 0;

      final histRows = await _client.query('''
        SELECT SUM(watched_seconds) as total_sec 
        FROM watch_histories 
        WHERE user_id = ?
      ''', [userId]);
      final totalSec = histRows.isNotEmpty && histRows.first['total_sec'] != null
          ? (histRows.first['total_sec'] is num ? (histRows.first['total_sec'] as num).toDouble() : double.tryParse(histRows.first['total_sec'].toString()) ?? 0.0)
          : 0.0;

      return UserProfileStats(
        totalEntries: total,
        completedCount: completed,
        currentCount: current,
        planningCount: planning,
        watchedEpisodesCount: watchedEps,
        totalWatchedHours: (totalSec / 3600.0),
      );
    } catch (_) {
      return const UserProfileStats();
    }
  }
  /// Récupère le classement des utilisateurs et les dashboards de la communauté.
  Future<CommunityDashboardData> getCommunityLeaderboard() async {
    try {
      final userRows = await _client.query('''
        SELECT 
          u.id,
          u.username,
          u.avatar_style,
          u.avatar_seed,
          u.avatar_url,
          u.bio,
          COUNT(DISTINCT CASE WHEN l.status = 'completed' THEN l.media_id END) as completed_count,
          COUNT(DISTINCT l.media_id) as total_animes,
          COALESCE(SUM(DISTINCT CASE WHEN p.watched = 1 THEN 1 ELSE 0 END), 0) as episodes_watched,
          COALESCE(ROUND(SUM(w.watched_seconds) / 3600.0, 1), 0.0) as watched_hours
        FROM users u
        LEFT JOIN list_entries l ON l.user_id = u.id
        LEFT JOIN episode_progresses p ON p.user_id = u.id
        LEFT JOIN watch_histories w ON w.user_id = u.id
        GROUP BY u.id
        ORDER BY watched_hours DESC, episodes_watched DESC, completed_count DESC
        LIMIT 50
      ''');

      final users = <LeaderboardUser>[];
      for (int i = 0; i < userRows.length; i++) {
        users.add(LeaderboardUser.fromMap(userRows[i], i + 1));
      }

      final topAnimeRows = await _client.query('''
        SELECT 
          m.anilist_id,
          m.anime_sama_title,
          m.title_romaji,
          m.cover_url,
          COUNT(l.user_id) as tracking_users
        FROM media_table m
        JOIN list_entries l ON l.media_id = m.anilist_id
        GROUP BY m.anilist_id
        ORDER BY tracking_users DESC
        LIMIT 5
      ''');

      final topAnimes = topAnimeRows.map(CommunityTopAnime.fromMap).toList();

      final globalRows = await _client.query('''
        SELECT 
          COUNT(DISTINCT u.id) as total_users,
          COUNT(DISTINCT l.media_id) as community_unique_animes,
          COALESCE(ROUND(SUM(w.watched_seconds) / 3600.0, 1), 0.0) as community_total_hours
        FROM users u
        LEFT JOIN list_entries l ON l.user_id = u.id
        LEFT JOIN watch_histories w ON w.user_id = u.id
      ''');

      final g = globalRows.isNotEmpty ? globalRows.first : <String, dynamic>{};
      final totalU = (g['total_users'] is int)
          ? g['total_users'] as int
          : int.tryParse(g['total_users']?.toString() ?? '') ?? users.length;
      final uniqueA = (g['community_unique_animes'] is int)
          ? g['community_unique_animes'] as int
          : int.tryParse(g['community_unique_animes']?.toString() ?? '') ?? 0;
      final totalH = (g['community_total_hours'] is num)
          ? (g['community_total_hours'] as num).toDouble()
          : double.tryParse(g['community_total_hours']?.toString() ?? '') ?? 0.0;

      return CommunityDashboardData(
        totalUsers: totalU,
        uniqueAnimes: uniqueA,
        totalHours: totalH,
        users: users,
        topAnimes: topAnimes,
      );
    } catch (_) {
      return const CommunityDashboardData();
    }
  }
}

/// Provider du repository d'authentification
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return AuthRepository(settings);
});

/// StateNotifier pour gérer l'utilisateur actuellement connecté
class CurrentUserNotifier extends StateNotifier<AsyncValue<UserAccount?>> {
  final AuthRepository _auth;

  CurrentUserNotifier(this._auth) : super(const AsyncValue.loading()) {
    init();
  }

  Future<void> init() async {
    try {
      final user = await _auth.restoreSession();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _auth.login(username, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String username,
    required String password,
    String? email,
    String avatarStyle = 'lorelei',
    String? avatarSeed,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _auth.register(
        username: username,
        password: password,
        email: email,
        avatarStyle: avatarStyle,
        avatarSeed: avatarSeed,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    await _auth.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> updateProfile({
    String? username,
    String? avatarStyle,
    String? avatarSeed,
    String? bio,
  }) async {
    final current = state.value;
    if (current == null) return;
    final updated = await _auth.updateProfile(
      current,
      username: username,
      avatarStyle: avatarStyle,
      avatarSeed: avatarSeed,
      bio: bio,
    );
    state = AsyncValue.data(updated);
  }
}

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserAccount?>>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return CurrentUserNotifier(auth);
});

/// Provider pour charger les stats de visionnage de l'utilisateur connecté
final currentUserStatsProvider = FutureProvider<UserProfileStats>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const UserProfileStats();
  final auth = ref.watch(authRepositoryProvider);
  return auth.getUserStats(user.id);
});

/// Provider pour charger le classement et les dashboards de la communauté
final communityDashboardProvider = FutureProvider<CommunityDashboardData>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  return auth.getCommunityLeaderboard();
});
