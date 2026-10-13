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
      'User-Agent': 'Terebi-App',
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
        apkUrl: latest.apkUrl,
        releaseNotes: latest.releaseNotes,
        releaseUrl: latest.releaseUrl,
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
    return downloadFile(
      url,
      fileName: 'terebi_update.zip',
      onProgress: onProgress,
      tempDir: tempDir,
    );
  }

  /// Télécharge un fichier (ZIP ou APK) avec suivi de progression.
  Future<File> downloadFile(
    String url, {
    String fileName = 'terebi_update.zip',
    void Function(double fraction)? onProgress,
    Directory? tempDir,
  }) async {
    final dir = tempDir ?? await getTemporaryDirectory();
    final dest = File('${dir.path}/$fileName');

    if (await dest.exists()) {
      try {
        await dest.delete();
      } catch (_) {}
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Terebi-App';
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
  /// Stratégie du swap différé :
  /// 1. Extraire le ZIP dans un dossier temporaire propre (`terebi_update_extracted`).
  /// 2. Écrire un script PowerShell qui :
  ///    - Attend l'arrêt du processus actuel (PID).
  ///    - Détecte l'arborescence extraite (racine ou dossier interne contenant terebi.exe).
  ///    - Vérifie les droits d'écriture sur le dossier d'installation (s'élève en admin si nécessaire).
  ///    - Copie récursivement les fichiers via Robocopy.
  ///    - Relance `terebi.exe` avec son WorkingDirectory correct.
  ///    - Nettoie les fichiers temporaires.
  /// 3. Lancer ce script en arrière-plan détaché, puis fermer l'app.
  Future<bool> installZip(File zipFile) async {
    if (!Platform.isWindows) {
      throw const UpdateError("L'installation automatique n'est disponible que sur Windows.");
    }
    final exePath = Platform.resolvedExecutable;
    final lowerExe = exePath.toLowerCase();
    if (!lowerExe.endsWith('.exe') || lowerExe.contains('dart.exe') || lowerExe.contains('flutter_tester')) {
      throw const UpdateError("L'installation automatique requiert l'exécutable compilé de Terebi.");
    }

    final exeDir = File(exePath).parent.path;
    final dir = zipFile.parent.path;
    final extractDir = '$dir\\terebi_update_extracted';
    final pid = _currentPid();

    // 1. Préparation du dossier d'extraction propre.
    final extractDirEntity = Directory(extractDir);
    if (await extractDirEntity.exists()) {
      try {
        await extractDirEntity.delete(recursive: true);
      } catch (_) {}
    }
    await extractDirEntity.create(recursive: true);

    // Extraction : tente d'abord tar.exe (Windows 10/11, instantané et robuste).
    var extracted = false;
    try {
      final tarRes = await Process.run(
        'tar.exe',
        ['-xf', zipFile.path, '-C', extractDir],
        runInShell: false,
      ).timeout(const Duration(minutes: 2));
      if (tarRes.exitCode == 0) {
        extracted = true;
      }
    } catch (_) {}

    // Fallback .NET ZipFile si tar.exe n'est pas disponible ou échoue.
    if (!extracted) {
      try {
        final psRes = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "Add-Type -AssemblyName System.IO.Compression.FileSystem; "
                "[System.IO.Compression.ZipFile]::ExtractToDirectory('${zipFile.path}', '$extractDir')",
          ],
          runInShell: false,
        ).timeout(const Duration(minutes: 3));
        if (psRes.exitCode == 0) {
          extracted = true;
        }
      } catch (_) {}
    }

    // Ultime recours : Expand-Archive
    if (!extracted) {
      final expandRes = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "Expand-Archive -Path '${zipFile.path}' -DestinationPath '$extractDir' -Force",
        ],
        runInShell: false,
      ).timeout(const Duration(minutes: 3));
      if (expandRes.exitCode != 0) {
        final err = expandRes.stderr.toString().trim();
        throw UpdateError('Extraction echouee (code ${expandRes.exitCode}) : $err');
      }
    }

    // 2. Script de swap différé
    final scriptPath = '$dir\\terebi_apply_update.ps1';
    final logPath = '$dir\\terebi_update.log';
    final script = '''
\$ErrorActionPreference = 'SilentlyContinue'
\$logFile = "$logPath"
"Demarrage de la mise a jour Terebi a \$(Get-Date)" | Out-File \$logFile

# Attend la fermeture de l'application (PID $pid), max ~30 s.
for (\$i = 0; \$i -lt 60; \$i++) {
  if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) { break }
  Start-Sleep -Milliseconds 500
}
if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
  Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
}
Get-Process -Name 'terebi' -ErrorAction SilentlyContinue | Where-Object { \$_.Path -eq "$exePath" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# Localisation du dossier source (gere le cas ou l'archive contient un dossier parent)
\$sourceDir = "$extractDir"
if (-not (Test-Path (Join-Path \$sourceDir "terebi.exe"))) {
  \$sub = Get-ChildItem -Path "$extractDir" -Directory | Where-Object { Test-Path (Join-Path \$_.FullName "terebi.exe") } | Select-Object -First 1
  if (\$sub) {
    \$sourceDir = \$sub.FullName
  }
}

# Verifie les droits d'ecriture sur le dossier d'installation (ex: Program Files)
\$canWrite = \$true
try {
  \$probe = Join-Path "$exeDir" ".terebi_probe"
  [System.IO.File]::WriteAllText(\$probe, "test")
  Remove-Item -Force \$probe -ErrorAction SilentlyContinue
} catch {
  \$canWrite = \$false
}

if (-not \$canWrite) {
  "Droits administrateur requis, re-execution via RunAs..." | Out-File \$logFile -Append
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"\$PSCommandPath`""
  exit
}

# Copie/fusion recursive
\$src = \$sourceDir.TrimEnd('\\')
\$dst = "$exeDir".TrimEnd('\\')
"Copie depuis \$src vers \$dst..." | Out-File \$logFile -Append
& robocopy \$src \$dst /E /IS /IT /NFL /NDL /NJH /NJS /NP /LOG+:\$logFile | Out-Null
\$code = \$LASTEXITCODE
"Code Robocopy : \$code" | Out-File \$logFile -Append

# Relance l'application mise a jour avec son WorkingDirectory correct
"Relance de l'app : $exePath dans \$dst" | Out-File \$logFile -Append
Start-Process -FilePath "$exePath" -WorkingDirectory "\$dst"

# Nettoyage
Start-Sleep -Seconds 2
Remove-Item -Recurse -Force "$extractDir" -ErrorAction SilentlyContinue
Remove-Item -Force "${zipFile.path}" -ErrorAction SilentlyContinue
Remove-Item -Force "\$PSCommandPath" -ErrorAction SilentlyContinue
''';
    await File(scriptPath).writeAsString(script);

    // 3. Lance le script en processus détaché
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
