@echo off
REM ---------------------------------------------------------
REM uninstall.bat
REM Startet Uninstall-EncryptPDF.ps1 mit Windows PowerShell 5.1
REM ---------------------------------------------------------
cd /d "%~dp0"

set "PS51=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS51%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-EncryptPDF.ps1"


