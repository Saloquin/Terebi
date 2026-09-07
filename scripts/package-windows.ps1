param(
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ReleaseDir  = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$DistDir     = Join-Path $ProjectRoot "dist"

$PubspecVersion = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern "^version:\s*(.+)").Matches[0].Groups[1].Value.Trim()
$Version = $PubspecVersion -replace '\+.*', ''

$ZipName = "terebi-$Version-windows-x64.zip"
$ZipPath = Join-Path $DistDir $ZipName

Write-Host "Terebi $Version -- packaging Windows x64" -ForegroundColor Cyan

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

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

if (Test-Path $ZipPath) { Remove-Item $ZipPath }

Write-Host "Creating $ZipName ..." -ForegroundColor Yellow
Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath

$SizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
Write-Host "Done -> dist\$ZipName ($SizeMB MB)" -ForegroundColor Green
Write-Host "To distribute: unzip and run terebi.exe from the extracted folder." -ForegroundColor Gray
