library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';
export 'update_models.dart';

class UpdateService {
  final http.Client httpClient;
  final String githubRepo;

  const UpdateService({
    required this.httpClient,
    required this.githubRepo,
  });

  static bool isNewer({required String current, required String latest}) =>
      isNewerVersion(current: current, latest: latest);

  Future<ReleaseInfo> fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$githubRepo/releases/latest',
    );
    final response = await httpClient.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw const UpdateError('Aucune release trouvee sur GitHub.');
    }
    if (response.statusCode != 200) {
      throw UpdateError('GitHub API : HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ReleaseInfo.fromGitHub(json);
  }

  Future<UpdateStatus> checkForUpdate(String currentVersion) async {
    try {
      final latest = await fetchLatestRelease();
      if (!isNewer(current: currentVersion, latest: latest.version)) {
        return UpdateUpToDate(currentVersion);
      }
      return UpdateAvailable(
        currentVersion: currentVersion,
        latestVersion: latest.version,
        zipUrl: latest.zipUrl,
      );
    } on UpdateError catch (e) {
      return e;
    } catch (e) {
      return UpdateError(e.toString());
    }
  }

  /// [tempDir] injectable pour les tests — null = utilise path_provider.
  Future<File> downloadZip(
    String url, {
    void Function(double fraction)? onProgress,
    Directory? tempDir,
  }) async {
    final dir = tempDir ?? await getTemporaryDirectory();
    final dest = File('${dir.path}/terebi_update.zip');

    final request = http.Request('GET', Uri.parse(url));
    final response =
        await httpClient.send(request).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw UpdateError('Telechargement echoue : HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = dest.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.flush();
    await sink.close();
    return dest;
  }

  /// Extrait le ZIP à côté de l'exe courant via PowerShell Expand-Archive.
  /// Remplace les fichiers en place — l'exe lui-même sera remplacé au prochain
  /// lancement (Windows ne verrouille pas les exe remplacés, seulement en cours
  /// d'exécution : l'ancien reste actif, le nouveau est utilisé au redémarrage).
  Future<bool> installZip(File zipFile) async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$exeDir" -Force',
      ],
      runInShell: false,
    ).timeout(const Duration(minutes: 3));

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw UpdateError(
          'Installation ZIP echouee (code ${result.exitCode}) : $stderr');
    }
    return true;
  }
}
