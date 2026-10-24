import 'package:test/test.dart';
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
}
