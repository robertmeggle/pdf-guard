#Requires -Version 5.1
param(
    [Parameter(Position=0)]
    [string]$Path  # wird vom Explorer als "%1" übergeben
)

$ErrorActionPreference = 'Stop'

# -----------------------------
# Logging + Hilfsfunktionen
# -----------------------------
$AppRoot = Join-Path $env:LOCALAPPDATA 'Encrypt-PDF'
$null = New-Item -ItemType Directory -Path $AppRoot -Force -ErrorAction SilentlyContinue
$LogPath = Join-Path $AppRoot 'run.log'
try { Start-Transcript -Path $LogPath -Append -ErrorAction SilentlyContinue } catch {}

function Show-Err([string]$msg) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show($msg, "Fehler", 'OK', 'Error') | Out-Null
    } catch {}
    Write-Error $msg
}

# -----------------------------
# STA sicherstellen (WinForms braucht STA)
# Falls nicht-STA: Selbst-Relaunch unter Windows PowerShell 5.1 mit -STA
# -----------------------------
try {
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
        $ps51  = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $self  = $MyInvocation.MyCommand.Definition
        $arg0  = if ($args.Count -ge 1) { $args[0] } elseif ($Path) { $Path } else { "" }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = $ps51
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$self`" `"$arg0`""
        $psi.UseShellExecute = $false

        [void][System.Diagnostics.Process]::Start($psi)
        exit 0
    }
} catch {
    Show-Err ("STA-Initialisierung fehlgeschlagen: " + $_.Exception.Message)
    exit 1
}

try {
    #Write-Host "== Encrypt-PDF gestartet =="
    #Write-Host "PSVersion: $($PSVersionTable.PSVersion)  Host: $($Host.Name)"
    #Write-Host "User: $(whoami)  PID: $PID"
    #Write-Host "PWD:  $((Get-Location).Path)"
    #Write-Host "Args: $($args -join ' | ')  Param-Path: $Path"

    # -----------------------------
    # Eingabedatei ermitteln
    # -----------------------------
    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ($args.Count -ge 1) { $Path = $args[0] }
    }
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Show-Err "Es wurde keine Datei $([char]0x00FC)bergeben."
        exit 1
    }

    $inPathResolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $inPathResolved) {
        Show-Err "Datei nicht gefunden: $Path"
        exit 1
    }
    $inPath = $inPathResolved.ProviderPath
    if ([IO.Path]::GetExtension($inPath).ToLowerInvariant() -ne ".pdf") {
        Show-Err "Die ausgew$([char]0x00E4)hlte Datei ist keine PDF: $inPath"
        exit 1
    }
    Write-Host "Input: $inPath"

    # -----------------------------
    # Assemblies laden (WinForms)
    # -----------------------------
    Add-Type -AssemblyName Microsoft.VisualBasic
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # -----------------------------
    # qpdf.exe suchen (unter %LOCALAPPDATA%\Encrypt-PDF\extTools\...)
    # -----------------------------
    $extTools = Join-Path $AppRoot 'extTools'
    if (-not (Test-Path -LiteralPath $extTools)) {
        Show-Err "Tools-Verzeichnis nicht gefunden: $extTools"
        exit 1
    }
    $qpdfPath = Get-ChildItem -LiteralPath $extTools -Recurse -Filter 'qpdf.exe' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName -First 1
    if (-not $qpdfPath) {
        Show-Err "qpdf.exe nicht gefunden unter: $extTools"
        exit 1
    }
    Write-Host "qpdf: $qpdfPath"

    # -----------------------------
    # Passwortdialog (maskiert, 2 Eingaben)
    # -----------------------------
    $form = New-Object Windows.Forms.Form
    $form.Text = "PDF sch$([char]0x00FC)tzen"   # "schützen"
    $form.Width = 360
    $form.Height = 190
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Icon = [System.Drawing.SystemIcons]::Shield  

    $lbl1 = New-Object Windows.Forms.Label
    $lbl1.Text = "Lesepasswort:"
    $lbl1.Left = 10; $lbl1.Top = 20; $lbl1.AutoSize = $true
    $tb1 = New-Object Windows.Forms.TextBox
    $tb1.Left = 130; $tb1.Top = 16; $tb1.Width = 200; $tb1.UseSystemPasswordChar = $true

    $lbl2 = New-Object Windows.Forms.Label
    $lbl2.Text = "Wiederholen:"
    $lbl2.Left = 10; $lbl2.Top = 60; $lbl2.AutoSize = $true
    $tb2 = New-Object Windows.Forms.TextBox
    $tb2.Left = 130; $tb2.Top = 56; $tb2.Width = 200; $tb2.UseSystemPasswordChar = $true

    $ok  = New-Object Windows.Forms.Button
    $ok.Text = "OK"; $ok.Left = 130; $ok.Top = 100; $ok.Width = 80
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $ok

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = "Abbrechen"; $cancel.Left = 220; $cancel.Top = 100; $cancel.Width = 110
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancel

    $form.Controls.AddRange(@($lbl1,$tb1,$lbl2,$tb2,$ok,$cancel))

    $dlg = $form.ShowDialog()
    if ($dlg -ne [System.Windows.Forms.DialogResult]::OK) { exit 1 }

    if ([string]::IsNullOrWhiteSpace($tb1.Text) -or ($tb1.Text -ne $tb2.Text)) {
        Show-Err "Passw$([char]0x00F6)rter stimmen nicht $([char]0x00FC)berein oder sind leer."
        exit 1
    }
    $user  = $tb1.Text
    $owner = $user  # falls gew$([char]0x00FC)nscht, hier eigenes Owner-Passwort setzen

    # -----------------------------
    # Ausgabedatei
    # -----------------------------
    $outPath = [IO.Path]::ChangeExtension($inPath, ".protected.pdf")
    Write-Host "Output: $outPath"

    if (Test-Path -LiteralPath $outPath) {
        $res = [System.Windows.Forms.MessageBox]::Show("Zieldatei existiert bereits:`n$outPath`n$([char]0x00DC)berschreiben?", "Best$([char]0x00E4)tigen", 'YesNo', 'Question')
        if ($res -ne [System.Windows.Forms.DialogResult]::Yes) { exit 1 }
        Remove-Item -LiteralPath $outPath -Force -ErrorAction Stop
    }

    # -----------------------------
    # qpdf aufrufen (sauber gequotet)
    # -----------------------------
    $argsQpdf = @(
        '--encrypt', $user, $owner, '256',
        '--modify=none',
        '--', $inPath, $outPath
    )
    Write-Host "Starte qpdf ..."
    & $qpdfPath @argsQpdf
    $code = $LASTEXITCODE
    Write-Host "qpdf ExitCode: $code"

    if ($code -ne 0 -or -not (Test-Path -LiteralPath $outPath)) {
        Show-Err "qpdf-Fehler (Exit $code)."
        exit $code
    }

    #[System.Windows.Forms.MessageBox]::Show("Erstellt:`n$outPath", "Fertig", 'OK', 'Information') | Out-Null
    Write-Host "OK"
    exit 0

} catch {
    Show-Err ("Unerwarteter Fehler: " + $_.Exception.Message)
    exit 1
} finally {
    try { Stop-Transcript | Out-Null } catch {}
}
