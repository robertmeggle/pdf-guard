#Requires -Version 5.1
<#
Zweck:
- Kopiert die App-Struktur nach %LOCALAPPDATA%\Encrypt-PDF
- Legt Explorer-Kontextmenüeintrag "PDF mit Passwort schützen" an:
  HKCU\Software\Classes\SystemFileAssociations\.pdf\shell\PDF mit Passwort schützen\command
Voraussetzung:
- Aktuelle Ordnerstruktur neben diesem Skript:
  .\app\Encrypt-PDF.ps1
  .\extTools\  (enthält portable qpdf-Version)
#>

$ErrorActionPreference = 'Stop'

# Quelle = Ordner des Installers (dieses Skript)
$srcRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
$appSrc   = Join-Path $srcRoot 'app\'

# Ziele
$targetRoot = Join-Path $env:LOCALAPPDATA 'Encrypt-PDF'
$appTarget  = $targetRoot                          # Skript-Ziel
$toolsTarget= Join-Path $targetRoot 'extTools'     # Tools-Ziel (qpdf etc.)

Write-Host "Quelle: $srcRoot"
Write-Host "Ziel:   $targetRoot"

# Verzeichnisse anlegen
New-Item -ItemType Directory -Path $appTarget  -Force | Out-Null
New-Item -ItemType Directory -Path $toolsTarget -Force | Out-Null

# Dateien kopieren
Write-Host "Kopiere Dateien..."
$scriptSrcFile = Join-Path $appSrc 'Encrypt-PDF.ps1'
if (-not (Test-Path -LiteralPath $scriptSrcFile)) {
    throw "App-Skript nicht gefunden: $scriptSrcFile"
}
Copy-Item -LiteralPath $scriptSrcFile -Destination (Join-Path $appTarget 'Encrypt-PDF.ps1') -Force 

$toolsSrcResolved = Resolve-Path -LiteralPath (Join-Path $srcRoot 'extTools') -ErrorAction Stop
if (-not (Test-Path -LiteralPath $toolsSrcResolved)) {
    throw "Tools-Ordner nicht gefunden: $toolsSrcResolved"
}

# Inhalte des Tools-Ordners rekursiv kopieren
Copy-Item -Path (Join-Path $toolsSrcResolved.ProviderPath '*') -Destination $toolsTarget -Recurse -Force 

Write-Host "Dateien sind kopiert."

# Optional: kurze Prüfung, ob qpdf.exe irgendwo unter extTools existiert
$qpdfProbe = Get-ChildItem -LiteralPath $toolsTarget -Recurse -Filter 'qpdf.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $qpdfProbe) {
    Write-Warning "Hinweis: Unter $toolsTarget wurde keine qpdf.exe gefunden. Bitte prüfe deine portable qpdf-Ablage."
} else {
    Write-Host "Gefundene qpdf.exe: $($qpdfProbe.FullName)"
}

Write-Host "Richte Kontextmenüeintrag ein..."

# Registry-Eintrag(e) anlegen (HKCU)
$baseKey = 'HKCU:\Software\Classes\SystemFileAssociations\.pdf\shell\PDF mit Passwort schützen'
$cmdKey  = Join-Path $baseKey 'command'

# Schlüssel anlegen
New-Item -Path $baseKey -Force | Out-Null
# Anzeigename im Kontextmenü
Set-ItemProperty -Path $baseKey -Name '(default)' -Value 'PDF mit Passwort schützen'

New-Item -Path $cmdKey -Force | Out-Null

# Befehl zusammensetzen (Pfad mit Anführungszeichen escapen)
$psFile = Join-Path $appTarget 'Encrypt-PDF.ps1'
$command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$psFile`" `"%1`""
Set-ItemProperty -Path $cmdKey -Name '(default)' -Value $command

#$ps51 = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
#$psFile = "$env:LOCALAPPDATA\Encrypt-PDF\Encrypt-PDF.ps1"
#$command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Start-Process -FilePath `"$ps51`" -ArgumentList '-NoProfile -ExecutionPolicy Bypass -STA -File `"$psFile`" `"%1`"' -WindowStyle Normal`""


Write-Host "Kontextmenüeintrag erstellt:"
Write-Host "  $baseKey"
Write-Host "  $cmdKey -> $command"
Write-Host "Fertig."
