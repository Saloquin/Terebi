param(
    [switch]$SkipBuild,
    [ValidateSet('all','windows','android','linux')]
    [string]$Platform = 'all'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$DistDir     = Join-Path $ProjectRoot "dist"

# --- Version ---
$PubspecVersion = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern "^version:\s*(.+)").Matches[0].Groups[1].Value.Trim()
$Version = $PubspecVersion -replace '\+.*', ''
$Tag     = "v$Version"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Terebi $Version — release multi-plateforme   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Prérequis
# ---------------------------------------------------------------------------

function Require($cmd, $msg) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw $msg }
}

Require "gh"      "GitHub CLI (gh) non trouve. Voir https://cli.github.com/"
Require "flutter" "Flutter non trouve dans le PATH."
Require "dart"    "Dart non trouve dans le PATH."

$buildWindows = $Platform -eq 'all' -or $Platform -eq 'windows'
$buildAndroid = $Platform -eq 'all' -or $Platform -eq 'android'
$buildLinux   = $Platform -eq 'all' -or $Platform -eq 'linux'

$artifacts = @()

# ---------------------------------------------------------------------------
# Windows — ZIP + MSIX
# ---------------------------------------------------------------------------

if ($buildWindows) {
    Write-Host "── Windows ─────────────────────────────────────" -ForegroundColor Magenta

    $ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    $ZipName    = "terebi-$Version-windows-x64.zip"
    $MsixName   = "terebi-$Version-windows-x64.msix"
    $ZipPath    = Join-Path $DistDir $ZipName
    $MsixPath   = Join-Path $DistDir $MsixName

    if (-not $SkipBuild) {
        Write-Host "  [build] flutter build windows --release ..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
        Pop-Location
    }

    if (-not (Test-Path (Join-Path $ReleaseDir "terebi.exe"))) {
        throw "terebi.exe introuvable dans $ReleaseDir"
    }

    Write-Host "  [zip]   $ZipName ..." -ForegroundColor Yellow
    if (Test-Path $ZipPath) { Remove-Item $ZipPath }
    Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath
    Write-Host "          OK ($([math]::Round((Get-Item $ZipPath).Length/1MB,1)) MB)" -ForegroundColor Green

    Write-Host "  [msix]  $MsixName ..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    dart run msix:create --output-path $DistDir --output-name "terebi-$Version-windows-x64"
    if ($LASTEXITCODE -ne 0) { throw "msix:create failed" }
    Pop-Location
    if (-not (Test-Path $MsixPath)) { throw "MSIX introuvable apres msix:create" }
    Write-Host "          OK ($([math]::Round((Get-Item $MsixPath).Length/1MB,1)) MB)" -ForegroundColor Green

    $artifacts += $ZipPath
    $artifacts += $MsixPath
}

# ---------------------------------------------------------------------------
# Android — APK universel + AAB (Play Store)
# ---------------------------------------------------------------------------

if ($buildAndroid) {
    Write-Host ""
    Write-Host "── Android ──────────────────────────────────────" -ForegroundColor Magenta

    $ApkSrc  = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    $AabSrc  = Join-Path $ProjectRoot "build\app\outputs\bundle\release\app-release.aab"
    $ApkDest = Join-Path $DistDir "terebi-$Version-android.apk"
    $AabDest = Join-Path $DistDir "terebi-$Version-android.aab"

    if (-not $SkipBuild) {
        Write-Host "  [build] flutter build apk --release ..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }
        Pop-Location

        Write-Host "  [build] flutter build appbundle --release ..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        flutter build appbundle --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed" }
        Pop-Location
    }

    if (Test-Path $ApkSrc) {
        Copy-Item $ApkSrc $ApkDest -Force
        Write-Host "  [apk]   OK ($([math]::Round((Get-Item $ApkDest).Length/1MB,1)) MB)" -ForegroundColor Green
        $artifacts += $ApkDest
    } else {
        Write-Warning "APK introuvable : $ApkSrc (ignore)"
    }

    if (Test-Path $AabSrc) {
        Copy-Item $AabSrc $AabDest -Force
        Write-Host "  [aab]   OK ($([math]::Round((Get-Item $AabDest).Length/1MB,1)) MB)" -ForegroundColor Green
        $artifacts += $AabDest
    } else {
        Write-Warning "AAB introuvable : $AabSrc (ignore)"
    }
}

# ---------------------------------------------------------------------------
# Linux — tar.gz (via Docker si disponible, sinon natif)
# ---------------------------------------------------------------------------

if ($buildLinux) {
    Write-Host ""
    Write-Host "── Linux ────────────────────────────────────────" -ForegroundColor Magenta

    $LinuxDest = Join-Path $DistDir "terebi-$Version-linux-x64.tar.gz"

    if (-not $SkipBuild) {
        $useDocker = Get-Command docker -ErrorAction SilentlyContinue
        if ($useDocker) {
            Write-Host "  [build] flutter build linux --release (Docker) ..." -ForegroundColor Yellow
            $proj = $ProjectRoot -replace '\\', '/'
            # Git Bash path : /c/... -> /c/...
            $projDocker = $proj -replace '^([A-Za-z]):', { '/' + $_.Value[0].ToString().ToLower() }
            & docker run --rm -v "${proj}:/app" -w /app terebi-ci `
                bash -c "flutter pub get >/dev/null 2>&1 && flutter build linux --release"
            if ($LASTEXITCODE -ne 0) { throw "flutter build linux (Docker) failed" }
        } else {
            Write-Host "  [build] flutter build linux --release (natif) ..." -ForegroundColor Yellow
            Push-Location $ProjectRoot
            flutter build linux --release
            if ($LASTEXITCODE -ne 0) { throw "flutter build linux failed" }
            Pop-Location
        }
    }

    $LinuxBundleDir = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
    if (Test-Path $LinuxBundleDir) {
        Write-Host "  [tar]   terebi-$Version-linux-x64.tar.gz ..." -ForegroundColor Yellow
        if (Test-Path $LinuxDest) { Remove-Item $LinuxDest }
        Push-Location (Split-Path $LinuxBundleDir -Parent)
        tar -czf $LinuxDest bundle
        if ($LASTEXITCODE -ne 0) { throw "tar failed" }
        Pop-Location
        Write-Host "          OK ($([math]::Round((Get-Item $LinuxDest).Length/1MB,1)) MB)" -ForegroundColor Green
        $artifacts += $LinuxDest
    } else {
        Write-Warning "Bundle Linux introuvable : $LinuxBundleDir (ignore)"
    }
}

# ---------------------------------------------------------------------------
# Upload GitHub Release
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "── GitHub Release $Tag ───────────────────────────" -ForegroundColor Magenta

if ($artifacts.Count -eq 0) {
    Write-Warning "Aucun artefact a uploader."
    exit 0
}

# Crée la release si absente
$null = gh release view $Tag --json tagName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Release $Tag absente — creation ..." -ForegroundColor DarkYellow
    gh release create $Tag `
        --title "Terebi $Version" `
        --notes "Release $Version — voir les commits pour le detail." `
        --latest
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
}

Write-Host "  Upload de $($artifacts.Count) artefact(s) ..." -ForegroundColor Yellow
gh release upload $Tag @artifacts --clobber
if ($LASTEXITCODE -ne 0) { throw "gh release upload failed" }

gh release edit $Tag --latest
if ($LASTEXITCODE -ne 0) { throw "gh release edit --latest failed" }

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   Release $Tag publiee avec succes !           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
foreach ($a in $artifacts) {
    Write-Host "  + $(Split-Path $a -Leaf)" -ForegroundColor Gray
}
Write-Host ""
gh release view $Tag --web 2>$null
