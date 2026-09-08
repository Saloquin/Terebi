// Importe uniquement update_models.dart (pas de path_provider/Flutter)
// pour rester compatible avec `dart test` sans dart:ui.
import 'package:terebi/src/services/update_models.dart';
import 'package:test/test.dart';

void main() {
  group('isNewerVersion', () {
    test('version plus recente disponible', () {
      expect(isNewerVersion(current: '1.0.0', latest: '1.1.0'), isTrue);
    });

    test('meme version : pas de mise a jour', () {
      expect(isNewerVersion(current: '1.1.0', latest: '1.1.0'), isFalse);
    });

    test('version courante plus recente : pas de mise a jour', () {
      expect(isNewerVersion(current: '1.2.0', latest: '1.1.0'), isFalse);
    });

    test('suffixe +build ignore dans la comparaison', () {
      expect(isNewerVersion(current: '1.0.0+2', latest: '1.1.0'), isTrue);
    });

    test('patch plus recent', () {
      expect(isNewerVersion(current: '1.0.0', latest: '1.0.1'), isTrue);
    });

    test('major plus recente', () {
      expect(isNewerVersion(current: '1.9.9', latest: '2.0.0'), isTrue);
    });
  });

  group('ReleaseInfo.fromGitHub', () {
    test('extrait tag et url ZIP', () {
      final json = {
        'tag_name': 'v1.2.3',
        'assets': [
          {
            'name': 'terebi-1.2.3-windows-x64.zip',
            'browser_download_url': 'https://example.com/terebi.zip',
          },
          {
            'name': 'terebi-1.2.3-android.apk',
            'browser_download_url': 'https://example.com/terebi.apk',
          },
        ],
      };
      final release = ReleaseInfo.fromGitHub(json);
      expect(release.version, equals('1.2.3'));
      expect(release.zipUrl, equals('https://example.com/terebi.zip'));
    });

    test('sans asset ZIP : zipUrl est null', () {
      final json = {
        'tag_name': 'v1.2.3',
        'assets': [
          {
            'name': 'terebi-1.2.3-android.apk',
            'browser_download_url': 'https://example.com/terebi.apk',
          },
        ],
      };
      final release = ReleaseInfo.fromGitHub(json);
      expect(release.zipUrl, isNull);
    });

    test('tag sans prefixe v', () {
      final json = {
        'tag_name': '2.0.0',
        'assets': <dynamic>[],
      };
      final release = ReleaseInfo.fromGitHub(json);
      expect(release.version, equals('2.0.0'));
    });

    test('assets vide', () {
      final json = {'tag_name': 'v1.0.0', 'assets': <dynamic>[]};
      final release = ReleaseInfo.fromGitHub(json);
      expect(release.version, equals('1.0.0'));
      expect(release.zipUrl, isNull);
    });
  });
}
