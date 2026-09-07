param(
    [switch]$SkipBuild,
    [switch]$MsixOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ReleaseDir  = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$DistDir     = Join-Path $ProjectRoot "dist"

$PubspecVersion = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern "^version:\s*(.+)").Matches[0].Groups[1].Value.Trim()
$Version = $PubspecVersion -replace '\+.*', ''

$ZipName  = "terebi-$Version-windows-x64.zip"
$MsixName = "terebi-$Version-windows-x64.msix"
$ZipPath  = Join-Path $DistDir $ZipName
$MsixPath = Join-Path $DistDir $MsixName

Write-Host "Terebi $Version -- packaging Windows x64" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# --- Build ------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "flutter build windows --release ..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
    Pop-Location
}

if (-not (Test-Path (Join-Path $ReleaseDir "terebi.exe"))) {
    throw "terebi.exe not found in $ReleaseDir -- run 'flutter build windows --release' first"
}

# --- ZIP (distribution manuelle) -------------------------------------------
if (-not $MsixOnly) {
    if (Test-Path $ZipPath) { Remove-Item $ZipPath }
    Write-Host "Creating $ZipName ..." -ForegroundColor Yellow
    Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath
    $SizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
    Write-Host "Done -> dist\$ZipName ($SizeMB MB)" -ForegroundColor Green
}

# --- MSIX (auto-update) -----------------------------------------------------
Write-Host "Building MSIX ($MsixName) ..." -ForegroundColor Yellow
Push-Location $ProjectRoot
dart run msix:create --output-path $DistDir --output-name "terebi-$Version-windows-x64"
if ($LASTEXITCODE -ne 0) { throw "msix:create failed -- check msix_config in pubspec.yaml" }
Pop-Location

if (Test-Path $MsixPath) {
    $SizeMB = [math]::Round((Get-Item $MsixPath).Length / 1MB, 1)
    Write-Host "Done -> dist\$MsixName ($SizeMB MB)" -ForegroundColor Green
} else {
    Write-Warning "MSIX not found at $MsixPath"
}

Write-Host ""
Write-Host "Distribution:" -ForegroundColor Cyan
Write-Host "  ZIP  : dist\$ZipName  (extract + run terebi.exe)" -ForegroundColor Gray
Write-Host "  MSIX : dist\$MsixName (auto-update via Add-AppxPackage)" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: MSIX install requires Developer Mode or a signed certificate." -ForegroundColor DarkYellow
Write-Host "Enable: Settings > Privacy > For developers > Developer Mode" -ForegroundColor DarkYellow
