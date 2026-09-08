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

function SizeMB {
    param($path)
    $bytes = (Get-Item $path).Length
    return [math]::Round($bytes / 1048576, 1)
}

Write-Host ''
Write-Host "=== Terebi $Version - release multi-plateforme ===" -ForegroundColor Cyan
Write-Host ''

# --- Prerequis flutter/dart ---
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter non trouve dans le PATH.' }
if (-not (Get-Command dart -ErrorAction SilentlyContinue))    { throw 'Dart non trouve dans le PATH.' }

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
# Windows - ZIP + MSIX
# ---------------------------------------------------------------------------
if ($buildWindows) {
    Write-Host '-- Windows --' -ForegroundColor Magenta

    $ReleaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
    $ZipName    = "terebi-$Version-windows-x64.zip"
    $MsixName   = "terebi-$Version-windows-x64.msix"
    $ZipPath    = Join-Path $DistDir $ZipName
    $MsixPath   = Join-Path $DistDir $MsixName

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

    $msixArg = "terebi-$Version-windows-x64"
    Write-Host "  [msix]  $MsixName" -ForegroundColor Yellow
    Push-Location $ProjectRoot
    dart run msix:create --output-path $DistDir --output-name $msixArg
    if ($LASTEXITCODE -ne 0) { throw 'msix:create failed' }
    Pop-Location
    if (-not (Test-Path $MsixPath)) { throw "MSIX introuvable apres msix:create" }
    $mb = SizeMB $MsixPath
    Write-Host "          OK $mb MB" -ForegroundColor Green

    $artifacts += $ZipPath
    $artifacts += $MsixPath
}

# ---------------------------------------------------------------------------
# Android - APK + AAB
# ---------------------------------------------------------------------------
if ($buildAndroid) {
    Write-Host ''
    Write-Host '-- Android --' -ForegroundColor Magenta

    $ApkSrc  = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-release.apk'
    $AabSrc  = Join-Path $ProjectRoot 'build\app\outputs\bundle\release\app-release.aab'
    $ApkDest = Join-Path $DistDir "terebi-$Version-android.apk"
    $AabDest = Join-Path $DistDir "terebi-$Version-android.aab"

    if (-not $SkipBuild) {
        Write-Host '  [build] flutter build apk --release' -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
        Pop-Location

        Write-Host '  [build] flutter build appbundle --release' -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build appbundle --release
        if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle failed' }
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

    if (Test-Path $AabSrc) {
        Copy-Item $AabSrc $AabDest -Force
        $mb = SizeMB $AabDest
        Write-Host "  [aab]   OK $mb MB" -ForegroundColor Green
        $artifacts += $AabDest
    } else {
        Write-Warning "AAB introuvable : $AabSrc (ignore)"
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
            Write-Host '  [build] flutter build linux --release (Docker)' -ForegroundColor Yellow
            $proj = $ProjectRoot -replace '\\', '/'
            docker run --rm -v "${proj}:/app" -w /app terebi-ci bash -c 'flutter pub get >/dev/null 2>&1 && flutter build linux --release'
            if ($LASTEXITCODE -ne 0) { throw 'flutter build linux (Docker) failed' }
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
gh release view $Tag --web 2>$null
