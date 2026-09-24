# Diagnostic auto-update Terebi — à lancer dans PowerShell
# Usage : powershell -File diag-update.ps1
# Ne modifie RIEN, ne fait qu'inspecter et rapporter.

$ErrorActionPreference = 'Continue'
Write-Host "=== 1. Process Terebi en cours ===" -ForegroundColor Cyan
$proc = Get-Process terebi -ErrorAction SilentlyContinue
if ($proc) {
    $proc | Select-Object Id, Path | Format-List
} else {
    Write-Host "  (aucun process 'terebi' en cours — lance l'app d'abord si tu veux son chemin)" -ForegroundColor Yellow
}

Write-Host "=== 2. Dossiers Terebi dans TEMP ===" -ForegroundColor Cyan
$temp = $env:TEMP
Write-Host "  TEMP = $temp"
$dirs = Get-ChildItem -Path $temp -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*erebi*" }
Write-Host "  Dossiers *erebi* trouvés : $($dirs.Count)"
$dirs | Select-Object -First 5 Name, LastWriteTime | Format-Table -AutoSize

Write-Host "=== 3. Fichiers d'update laissés dans TEMP ===" -ForegroundColor Cyan
Get-ChildItem -Path $temp -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "terebi_update*" -or $_.Name -like "terebi_apply*" } |
    Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize

$extractDir = Join-Path $temp "terebi_update_extracted"
if (Test-Path $extractDir) {
    Write-Host "  Contenu de terebi_update_extracted (racine) :" -ForegroundColor Yellow
    Get-ChildItem -Path $extractDir -ErrorAction SilentlyContinue |
        Select-Object -First 10 Name, Mode | Format-Table -AutoSize
    Write-Host "  terebi.exe present a la racine de l'extract ? " -NoNewline
    Write-Host (Test-Path (Join-Path $extractDir "terebi.exe")) -ForegroundColor Green
} else {
    Write-Host "  (pas de dossier terebi_update_extracted actuellement)" -ForegroundColor Yellow
}

Write-Host "=== 4. Script de swap laisse ? ===" -ForegroundColor Cyan
$scriptPath = Join-Path $temp "terebi_apply_update.ps1"
if (Test-Path $scriptPath) {
    Write-Host "  terebi_apply_update.ps1 EXISTE — contenu :" -ForegroundColor Yellow
    Get-Content $scriptPath
} else {
    Write-Host "  (pas de terebi_apply_update.ps1 — soit deja nettoye, soit jamais cree)" -ForegroundColor Yellow
}

Write-Host "=== 5. robocopy disponible ? ===" -ForegroundColor Cyan
$rc = Get-Command robocopy -ErrorAction SilentlyContinue
Write-Host "  robocopy : $(if ($rc) { $rc.Source } else { 'INTROUVABLE' })"

Write-Host ""
Write-Host "=== Copie-colle TOUT ce qui precede ===" -ForegroundColor Green
