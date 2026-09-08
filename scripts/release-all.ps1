param(
    [switch]$SkipBuild,
    [ValidateSet('all','windows','android','linux')]
    [string]$Platform = 'all'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$DistDir = Join-Path $ProjectRoot 'dist'

$PubspecVersion = (Select-String -Path (Join-Path $ProjectRoot 'pubspec.yaml') -Pattern '^version:\s*(.+)').Matches[0].Groups[1].Value.Trim()
$Version = $PubspecVersion -replace '\+.*', ''
$Tag = "v$Version"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null


# --- Localise Flutter si absent du PATH ---
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $candidates = @(
        "$env:USERPROFILE\flutter\bin",
        "$env:USERPROFILE\development\flutter\bin",
        "$env:USERPROFILE\Documents\flutter\bin",
        'C:\flutter\bin',
        'C:\development\flutter\bin',
        'C:\src\flutter\bin',
        "$env:LOCALAPPDATA\flutter\bin"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'flutter.bat')) {
            $env:PATH = $c + ';' + $env:PATH
            Write-Host "  Flutter trouve : $c" -ForegroundColor DarkGray
            break
        }
    }
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter introuvable. Ajoute le dossier bin de Flutter dans ton PATH, ou installe Flutter depuis https://flutter.dev'
    }
}

function SizeMB {
    param($path)
    $bytes = (Get-Item $path).Length
    return [math]::Round($bytes / 1048576, 1)
}

Write-Host ''
Write-Host "=== Terebi $Version - release multi-plateforme ===" -ForegroundColor Cyan
Write-Host ''

# --- Installe gh si absent ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host 'GitHub CLI absent - installation via winget...' -ForegroundColor Yellow
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'Installation de gh echouee. Voir https://cli.github.com/' }
    $machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH    = $machinePath + ';' + $userPath
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'gh installe mais introuvable. Redemarre PowerShell et relance le script.'
    }
    Write-Host 'Connexion GitHub requise...' -ForegroundColor Yellow
    gh auth login
}

$buildWindows = ($Platform -eq 'all') -or ($Platform -eq 'windows')
$buildAndroid = ($Platform -eq 'all') -or ($Platform -eq 'android')
$buildLinux   = ($Platform -eq 'all') -or ($Platform -eq 'linux')

$artifacts = @()

# ---------------------------------------------------------------------------
# Windows - ZIP
# ---------------------------------------------------------------------------
if ($buildWindows) {
    Write-Host '-- Windows --' -ForegroundColor Magenta

    $ReleaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
    $ZipName    = "terebi-$Version-windows-x64.zip"
    $ZipPath    = Join-Path $DistDir $ZipName

    if (-not $SkipBuild) {
        Write-Host '  [build] flutter build windows --release' -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }
        Pop-Location
    }

    if (-not (Test-Path (Join-Path $ReleaseDir 'terebi.exe'))) {
        throw "terebi.exe introuvable dans $ReleaseDir"
    }

    Write-Host "  [zip]   $ZipName" -ForegroundColor Yellow
    if (Test-Path $ZipPath) { Remove-Item $ZipPath }
    Compress-Archive -Path (Join-Path $ReleaseDir '*') -DestinationPath $ZipPath
    $mb = SizeMB $ZipPath
    Write-Host "          OK $mb MB" -ForegroundColor Green

    $artifacts += $ZipPath
}

# ---------------------------------------------------------------------------
# Android - APK uniquement (AAB : stripping symboles natifs echoue avec media_kit)
# ---------------------------------------------------------------------------
if ($buildAndroid) {
    Write-Host ''
    Write-Host '-- Android --' -ForegroundColor Magenta

    $ApkSrc  = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-release.apk'
    $ApkDest = Join-Path $DistDir "terebi-$Version-android.apk"

    if (-not $SkipBuild) {
        Write-Host '  [build] flutter build apk --release' -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
        Pop-Location
    }

    if (Test-Path $ApkSrc) {
        Copy-Item $ApkSrc $ApkDest -Force
        $mb = SizeMB $ApkDest
        Write-Host "  [apk]   OK $mb MB" -ForegroundColor Green
        $artifacts += $ApkDest
    } else {
        Write-Warning "APK introuvable : $ApkSrc (ignore)"
    }
}

# ---------------------------------------------------------------------------
# Linux - tar.gz (Docker si disponible, sinon natif)
# ---------------------------------------------------------------------------
if ($buildLinux) {
    Write-Host ''
    Write-Host '-- Linux --' -ForegroundColor Magenta

    $LinuxDest      = Join-Path $DistDir "terebi-$Version-linux-x64.tar.gz"
    $LinuxBundleDir = Join-Path $ProjectRoot 'build\linux\x64\release\bundle'

    if (-not $SkipBuild) {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            # Verifie que l'image terebi-ci existe localement
            $imageExists = docker image inspect terebi-ci 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host '  [build] flutter build linux --release (Docker)' -ForegroundColor Yellow
                $proj = $ProjectRoot -replace '\\', '/'
                docker run --rm -v "${proj}:/app" -w /app terebi-ci bash -c 'flutter pub get >/dev/null 2>&1 && flutter build linux --release'
                if ($LASTEXITCODE -ne 0) { throw 'flutter build linux (Docker) failed' }
            } else {
                Write-Warning "Image Docker terebi-ci absente — build Linux ignore."
                Write-Warning "Pour la construire : docker build -f Dockerfile.flutter-ci -t terebi-ci ."
            }
        } else {
            Write-Host '  [build] flutter build linux --release (natif)' -ForegroundColor Yellow
            Push-Location $ProjectRoot
            flutter build linux --release
            if ($LASTEXITCODE -ne 0) { throw 'flutter build linux failed' }
            Pop-Location
        }
    }

    if (Test-Path $LinuxBundleDir) {
        Write-Host "  [tar]   terebi-$Version-linux-x64.tar.gz" -ForegroundColor Yellow
        if (Test-Path $LinuxDest) { Remove-Item $LinuxDest }
        Push-Location (Split-Path $LinuxBundleDir -Parent)
        tar -czf $LinuxDest bundle
        if ($LASTEXITCODE -ne 0) { throw 'tar failed' }
        Pop-Location
        $mb = SizeMB $LinuxDest
        Write-Host "          OK $mb MB" -ForegroundColor Green
        $artifacts += $LinuxDest
    } else {
        Write-Warning "Bundle Linux introuvable : $LinuxBundleDir (ignore)"
    }
}

# ---------------------------------------------------------------------------
# Upload GitHub Release
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host "-- GitHub Release $Tag --" -ForegroundColor Magenta

if ($artifacts.Count -eq 0) {
    Write-Warning 'Aucun artefact a uploader.'
    exit 0
}

gh release view $Tag --json tagName 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Release $Tag absente - creation" -ForegroundColor DarkYellow
    gh release create $Tag --title "Terebi $Version" --notes "Release $Version" --latest
    if ($LASTEXITCODE -ne 0) { throw 'gh release create failed' }
}

$count = $artifacts.Count
Write-Host "  Upload de $count artefact(s)" -ForegroundColor Yellow
gh release upload $Tag @artifacts --clobber
if ($LASTEXITCODE -ne 0) { throw 'gh release upload failed' }

gh release edit $Tag --latest
if ($LASTEXITCODE -ne 0) { throw 'gh release edit --latest failed' }

Write-Host ''
Write-Host "=== Release $Tag publiee avec succes ===" -ForegroundColor Green
Write-Host ''
foreach ($a in $artifacts) {
    $leaf = Split-Path $a -Leaf
    Write-Host "  + $leaf" -ForegroundColor Gray
}
Write-Host ''
gh release view $Tag --web 2>$null | Out-Null
