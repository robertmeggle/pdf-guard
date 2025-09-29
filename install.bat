@echo off
REM ---------------------------------------------------------
REM install.bat
REM Startet Install-EncryptPDF.ps1 mit Windows PowerShell 5.1
REM ---------------------------------------------------------
REM Arbeitsverzeichnis auf Ordner der Batch-Datei setzen
cd /d "%~dp0"

REM Pfad zur Windows PowerShell 5.1 (System32)
set "PS51=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"

REM Installationsskript ausführen (ExecutionPolicy temporär bypass)
"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-EncryptPDF.ps1"


