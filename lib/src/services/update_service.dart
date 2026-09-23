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

  /// Installe la mise à jour Windows (ZIP) puis redémarre l'application.
  ///
  /// On NE peut PAS écraser `terebi.exe` pendant qu'il tourne : Windows verrouille
  /// tout exécutable en cours. `Expand-Archive` par-dessus l'exe échoue (ou laisse
  /// l'ancien exe en place → l'app relancée reste à l'ancienne version).
  ///
  /// Stratégie du swap différé :
  /// 1. Extraire le ZIP dans un dossier temporaire (`terebi_update_extracted`).
  /// 2. Écrire un script PowerShell qui : attend la fermeture de CE process
  ///    (par PID), copie le contenu extrait par-dessus le dossier de l'exe
  ///    (exe inclus, désormais déverrouillé), puis relance l'app.
  /// 3. Lancer ce script en processus DÉTACHÉ, puis quitter l'app.
  ///
  /// Retourne `true` une fois le script de swap lancé (l'app doit alors quitter).
  Future<bool> installZip(File zipFile) async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    final dir = zipFile.parent.path;
    final extractDir = '$dir\\terebi_update_extracted';
    final pid = _currentPid();

    // 1. Extraction dans un dossier temporaire propre (jamais par-dessus l'exe).
    final extract = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'if (Test-Path "$extractDir") { Remove-Item -Recurse -Force "$extractDir" }; '
            'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$extractDir" -Force',
      ],
      runInShell: false,
    ).timeout(const Duration(minutes: 3));

    if (extract.exitCode != 0) {
      final err = extract.stderr.toString().trim();
      throw UpdateError('Extraction echouee (code ${extract.exitCode}) : $err');
    }

    // 2. Script de swap différé : attend la fin du process courant, copie par
    //    dessus l'exe (déverrouillé), relance l'app, nettoie le temporaire.
    final scriptPath = '$dir\\terebi_apply_update.ps1';
    final script = '''
\$ErrorActionPreference = 'SilentlyContinue'
# Attend la fermeture de l'application (PID $pid), max ~30 s.
for (\$i = 0; \$i -lt 60; \$i++) {
  if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) { break }
  Start-Sleep -Milliseconds 500
}
Start-Sleep -Milliseconds 500
# Copie/fusion recursive des nouveaux fichiers par-dessus l'installation (exe
# desormais deverrouille). robocopy /E fusionne les sous-dossiers et remplace
# les fichiers ; ses codes de sortie < 8 sont des succes.
robocopy "$extractDir" "$exeDir" /E /IS /IT /NFL /NDL /NJH /NJS /NP | Out-Null
# Relance l'application mise a jour.
Start-Process -FilePath "$exePath"
# Nettoyage best-effort.
Remove-Item -Recurse -Force "$extractDir"
Remove-Item -Force "${zipFile.path}"
Remove-Item -Force "\$PSCommandPath"
''';
    await File(scriptPath).writeAsString(script);

    // 3. Lance le script en processus détaché (survit à la fermeture de l'app).
    await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
      ],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    return true;
  }

  /// PID du process courant (l'app Flutter). `pid` global de dart:io.
  int _currentPid() => pid;
}
