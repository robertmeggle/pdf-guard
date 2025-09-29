#Requires -Version 5.1
<#
Zweck:
- Entfernt Explorer-Kontextmenüeintrag "PDF mit Passwort schützen"
- Löscht %LOCALAPPDATA%\Encrypt-PDF
#>

$ErrorActionPreference = 'Stop'

$targetRoot = Join-Path $env:LOCALAPPDATA 'Encrypt-PDF'

# Registry-Schlüssel entfernen
$baseKey = 'HKCU:\Software\Classes\SystemFileAssociations\.pdf\shell\PDF mit Passwort schützen'

if (Test-Path -LiteralPath $baseKey) {
    Remove-Item -LiteralPath $baseKey -Recurse -Force
    Write-Host "Registry entfernt: $baseKey"
} else {
    Write-Host "Registry-Schlüssel nicht vorhanden: $baseKey"
}

# Zielordner löschen
if (Test-Path -LiteralPath $targetRoot) {
    Remove-Item -LiteralPath $targetRoot -Recurse -Force
    Write-Host "Ordner gelöscht: $targetRoot"
} else {
    Write-Host "Ordner nicht vorhanden: $targetRoot"
}

Write-Host "Deinstallation abgeschlossen."
