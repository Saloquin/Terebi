param(
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ReleaseDir  = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$DistDir     = Join-Path $ProjectRoot "dist"

# --- Version depuis pubspec.yaml ---
$PubspecVersion = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern "^version:\s*(.+)").Matches[0].Groups[1].Value.Trim()
$Version = $PubspecVersion -replace '\+.*', ''
$Tag     = "v$Version"

$ZipName  = "terebi-$Version-windows-x64.zip"
$MsixName = "terebi-$Version-windows-x64.msix"
$ZipPath  = Join-Path $DistDir $ZipName
$MsixPath = Join-Path $DistDir $MsixName

Write-Host ""
Write-Host "=== Terebi $Version — release Windows x64 ===" -ForegroundColor Cyan
Write-Host ""

# --- Prérequis : gh CLI ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) non trouve. Installe-le depuis https://cli.github.com/"
}

# --- Prérequis : flutter ---
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter non trouve dans le PATH."
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# --- Build Flutter Windows ---
if (-not $SkipBuild) {
    Write-Host "[1/4] flutter build windows --release ..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
    Pop-Location
} else {
    Write-Host "[1/4] Build ignore (-SkipBuild)" -ForegroundColor DarkGray
}

if (-not (Test-Path (Join-Path $ReleaseDir "terebi.exe"))) {
    throw "terebi.exe introuvable dans $ReleaseDir -- lance 'flutter build windows --release' d'abord"
}

# --- ZIP ---
Write-Host "[2/4] Creation du ZIP ($ZipName) ..." -ForegroundColor Yellow
if (Test-Path $ZipPath) { Remove-Item $ZipPath }
Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath
$ZipMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
Write-Host "      -> dist\$ZipName ($ZipMB MB)" -ForegroundColor Green

# --- MSIX ---
Write-Host "[3/4] Creation du MSIX ($MsixName) ..." -ForegroundColor Yellow
Push-Location $ProjectRoot
dart run msix:create --output-path $DistDir --output-name "terebi-$Version-windows-x64"
if ($LASTEXITCODE -ne 0) { throw "msix:create failed -- verifie msix_config dans pubspec.yaml" }
Pop-Location

if (Test-Path $MsixPath) {
    $MsixMB = [math]::Round((Get-Item $MsixPath).Length / 1MB, 1)
    Write-Host "      -> dist\$MsixName ($MsixMB MB)" -ForegroundColor Green
} else {
    throw "MSIX introuvable apres msix:create : $MsixPath"
}

# --- Upload sur la release GitHub ---
Write-Host "[4/4] Upload sur la release GitHub $Tag ..." -ForegroundColor Yellow

# Verifie que la release existe ; la cree si absente
$ReleaseExists = gh release view $Tag --json tagName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Release $Tag absente — creation automatique..." -ForegroundColor DarkYellow
    gh release create $Tag `
        --title "Terebi $Version" `
        --notes "Release $Version — voir CHANGELOG ou les commits pour le detail." `
        --latest
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
}

# Upload les deux artefacts (--clobber ecrase si deja presents)
gh release upload $Tag $ZipPath $MsixPath --clobber
if ($LASTEXITCODE -ne 0) { throw "gh release upload failed" }

# Marque la release comme latest
gh release edit $Tag --latest
if ($LASTEXITCODE -ne 0) { throw "gh release edit --latest failed" }

Write-Host ""
Write-Host "=== Release $Tag publiee ===" -ForegroundColor Cyan
Write-Host "  ZIP  : dist\$ZipName" -ForegroundColor Gray
Write-Host "  MSIX : dist\$MsixName" -ForegroundColor Gray
gh release view $Tag --web 2>$null
Write-Host ""
Write-Host "Note : le MSIX necessite le Mode Developpeur ou un certificat signe." -ForegroundColor DarkYellow
Write-Host "  Activer : Parametres > Confidentialite > Pour les developpeurs > Mode developpeur" -ForegroundColor DarkYellow
