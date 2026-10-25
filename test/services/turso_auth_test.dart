import 'dart:convert';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:terebi/src/data/local/database.dart';
import 'package:terebi/src/data/repositories/auth_repository.dart';
import 'package:terebi/src/data/repositories/settings_repository.dart';
import 'package:terebi/src/domain/models/user_account.dart';
import 'package:terebi/src/data/remote/turso_client.dart';

void main() {
  group('UserAccount & DiceBear', () {
    test('avatarPngUrl génère correctement les URLs DiceBear', () {
      final user = UserAccount(
        id: '123',
        username: 'Thomas',
        avatarStyle: 'lorelei',
        avatarSeed: 'Thomas',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(
        user.avatarPngUrl,
        'https://api.dicebear.com/9.x/lorelei/png?seed=Thomas',
      );
    });

    test('avatarPngUrl encode correctement les espaces ou caractères spéciaux', () {
      final user = UserAccount(
        id: '123',
        username: 'Thomas Le Grand',
        avatarStyle: 'bottts',
        avatarSeed: 'Super Seed!',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(
        user.avatarPngUrl,
        'https://api.dicebear.com/9.x/bottts/png?seed=Super%20Seed!',
      );
    });

    test('sérialisation toMap et fromMap', () {
      final user = UserAccount(
        id: 'user_abc',
        username: 'Saloquin',
        email: 'saloquin@test.com',
        avatarStyle: 'adventurer',
        avatarSeed: 'seed123',
        bio: 'Fan d\'animes',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final map = user.toMap();
      final restored = UserAccount.fromMap(map);

      expect(restored.id, 'user_abc');
      expect(restored.username, 'Saloquin');
      expect(restored.email, 'saloquin@test.com');
      expect(restored.avatarStyle, 'adventurer');
      expect(restored.avatarSeed, 'seed123');
      expect(restored.bio, 'Fan d\'animes');
    });
  });

  group('TursoClient URL & Parsing', () {
    test('normalise les URLs libsql:// en https://.../v2/pipeline', () {
      final client = TursoClient(
        url: 'libsql://terebi-saloquin.aws-eu-west-1.turso.io',
        token: 'test_token',
      );

      expect(
        client.baseUrl,
        'https://terebi-saloquin.aws-eu-west-1.turso.io/v2/pipeline',
      );
    });

    test('normalise les URLs https:// directes', () {
      final client = TursoClient(
        url: 'https://terebi-saloquin.aws-eu-west-1.turso.io/',
        token: 'test_token',
      );

      expect(
        client.baseUrl,
        'https://terebi-saloquin.aws-eu-west-1.turso.io/v2/pipeline',
      );
    });
  });

  group('AuthRepository & Reconnection Persistence', () {
    late TerebiDatabase db;
    late SettingsRepository settings;
    late AuthRepository authRepo;

    final dummyUser = UserAccount(
      id: 'usr_persistent_42',
      username: 'Saloquin',
      avatarStyle: 'lorelei',
      avatarSeed: 'tyxcz7oe',
      bio: 'Membre actif Terebi',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    setUp(() {
      db = TerebiDatabase(NativeDatabase.memory());
      settings = SettingsRepository(db);
      authRepo = AuthRepository(settings);
    });

    tearDown(() async {
      await db.close();
    });

    test('getCachedUser retourne le profil immédiatement sans appel réseau', () async {
      await settings.set('auth_cached_user', jsonEncode(dummyUser.toMap()));

      final cached = await authRepo.getCachedUser();
      expect(cached, isNotNull);
      expect(cached!.id, 'usr_persistent_42');
      expect(cached.username, 'Saloquin');
      expect(cached.avatarStyle, 'lorelei');
    });

    test('restoreSession conserve le compte utilisateur même si offline ou erreur serveur', () async {
      await settings.set('auth_session_token', 'fake_offline_token_xyz');
      await settings.set('auth_cached_user', jsonEncode(dummyUser.toMap()));

      final restored = await authRepo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.id, 'usr_persistent_42');
      expect(restored.username, 'Saloquin');

      // Le token local et le cache ne doivent JAMAIS avoir été supprimés
      expect(await settings.get('auth_session_token'), 'fake_offline_token_xyz');
      expect(await settings.get('auth_cached_user'), isNotNull);
    });

    test('logout efface définitivement le token et le cache local', () async {
      await settings.set('auth_session_token', 'token_to_purge');
      await settings.set('auth_user_id', 'usr_persistent_42');
      await settings.set('auth_cached_user', jsonEncode(dummyUser.toMap()));

      await authRepo.logout();

      expect(await settings.get('auth_session_token'), isNull);
      expect(await settings.get('auth_user_id'), isNull);
      expect(await settings.get('auth_cached_user'), isNull);
      expect(await authRepo.getCachedUser(), isNull);
    });
  });
}
