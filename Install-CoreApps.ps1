#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and restores settings for the 5 JR core apps on a new machine.
    Run AFTER Backup-CoreApps.ps1 has been run on source machine.

.PARAMETER BundleRoot
    Path to the CoreApps-Bundle\ folder (default: same folder as this script).

.PARAMETER MacriumVersion
    Which Macrium Reflect to install: 7 or 8 (default: 7)

.PARAMETER SkipInstallers
    Switch: skip installation, only restore settings (useful if apps already installed).

.NOTES
    Run as Administrator. Reboot required after ExplorerPatcher.
#>
param(
    [string]$BundleRoot      = (Join-Path $PSScriptRoot "CoreApps-Bundle"),
    [ValidateSet(7, 8)]
    [int]$MacriumVersion     = 7,
    [switch]$SkipInstallers
)

$ErrorActionPreference = 'Continue'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Warning "Not running as Administrator. Some steps may fail."
    Write-Warning "Right-click PowerShell -> Run as Administrator"
    Write-Host ""
}

$SettingsDir = Join-Path $BundleRoot "settings"
$InstDir     = Join-Path $BundleRoot "installers"

if (!(Test-Path $BundleRoot)) {
    Write-Error "Bundle not found: $BundleRoot`nRun Backup-CoreApps.ps1 on source machine first."
    exit 1
}

$ok  = [System.Collections.Generic.List[string]]::new()
$err = [System.Collections.Generic.List[string]]::new()
$rebootNeeded = $false

function Step($label, [scriptblock]$body) {
    Write-Host "  $label ... " -NoNewline
    try {
        & $body
        $ok.Add($label)
        Write-Host "OK" -ForegroundColor Green
    } catch {
        $err.Add("$label -- $_")
        Write-Host "FAILED: $_" -ForegroundColor Red
    }
}

function WaitForProcess($exePath, $timeoutSec = 120) {
    $proc = Start-Process $exePath -PassThru
    $proc.WaitForExit($timeoutSec * 1000) | Out-Null
    return $proc.ExitCode
}

Write-Host ""
Write-Host "  CoreApps Installer  --  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "  Bundle:  $BundleRoot" -ForegroundColor DarkGray
Write-Host "  Macrium: v$MacriumVersion" -ForegroundColor DarkGray
Write-Host "  Mode:    $(if ($SkipInstallers) { 'Settings-restore only' } else { 'Install + restore' })" -ForegroundColor DarkGray
Write-Host ""

# -- INSTALL PHASE --------------------------------------------------------------

if (!$SkipInstallers) {

    # 1. 8GadgetPack -- MSI silent
    Step "Install 8GadgetPack v31 (MSI)" {
        $msi = Get-ChildItem "$InstDir\8gadgetpack\*.msi" | Select-Object -First 1
        if (!$msi) { throw "8GadgetPack MSI not found in $InstDir\8gadgetpack\" }
        $exit = (Start-Process msiexec -ArgumentList "/i `"$($msi.FullName)`" /quiet /norestart" -Wait -PassThru).ExitCode
        if ($exit -ne 0 -and $exit -ne 3010) { throw "msiexec exited $exit" }
    }

    # 2. ExplorerPatcher -- runs its own installer (no reliable silent flag; uses /S for NSIS-style)
    Step "Install ExplorerPatcher" {
        $exe = Get-ChildItem "$InstDir\explorerpatcher\ep_setup*.exe" |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (!$exe) { throw "ep_setup not found in $InstDir\explorerpatcher\" }
        # ExplorerPatcher uses /S for unattended install
        $exit = (Start-Process $exe.FullName -ArgumentList "/S" -Wait -PassThru).ExitCode
        if ($exit -ne 0) { Write-Warning "ep_setup exited $exit (may still have installed OK)" }
        $script:rebootNeeded = $true
    }

    # 3. Open Shell -- Ninite installer runs silently by default (no user prompts)
    Step "Install Open Shell (Ninite)" {
        $exe = Get-ChildItem "$InstDir\openshell\*.exe" | Select-Object -First 1
        if (!$exe) { throw "Open Shell installer not found in $InstDir\openshell\" }
        $exit = (Start-Process $exe.FullName -Wait -PassThru).ExitCode
        if ($exit -ne 0) { throw "Ninite exited $exit" }
    }

    # 4. Core Temp -- NSIS installer
    Step "Install Core Temp v1.18.1" {
        $exe = Get-ChildItem "$InstDir\coretemp\*.exe" | Select-Object -First 1
        if (!$exe) { throw "Core Temp installer not found in $InstDir\coretemp\" }
        $exit = (Start-Process $exe.FullName -ArgumentList "/S" -Wait -PassThru).ExitCode
        if ($exit -ne 0) { throw "Core Temp installer exited $exit" }
    }

    # 5. Macrium Reflect -- InnoSetup silent flags
    Step "Install Macrium Reflect v$MacriumVersion" {
        $pattern = if ($MacriumVersion -eq 7) { "*v7*" } else { "*v8*" }
        $exe = Get-ChildItem "$InstDir\macrium\$pattern" | Select-Object -First 1
        if (!$exe) { throw "Macrium v$MacriumVersion installer not found in $InstDir\macrium\" }
        $exit = (Start-Process $exe.FullName -ArgumentList "/verysilent /norestart" -Wait -PassThru).ExitCode
        if ($exit -ne 0) { throw "Macrium installer exited $exit" }
    }
}

# -- SETTINGS RESTORE PHASE -----------------------------------------------------

Write-Host ""
Write-Host "  -- Restoring settings --" -ForegroundColor Cyan

# 1. 8GadgetPack -- settings.ini + Gadgets library
Step "Restore 8GadgetPack settings.ini" {
    $dst = "$env:LOCALAPPDATA\Microsoft\Windows Sidebar"
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    $src = "$SettingsDir\8gadgetpack\settings.ini"
    if (!(Test-Path $src)) { throw "settings.ini not in bundle" }
    Copy-Item $src "$dst\settings.ini" -Force
}

Step "Restore 8GadgetPack Gadgets library" {
    $dst = "$env:LOCALAPPDATA\Microsoft\Windows Sidebar\Gadgets"
    $zip = "$SettingsDir\8gadgetpack\Gadgets.zip"
    if (!(Test-Path $zip)) { throw "Gadgets.zip not in bundle" }
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dst)
}

# 2. ExplorerPatcher -- registry import
Step "Restore ExplorerPatcher registry" {
    $reg = "$SettingsDir\explorerpatcher\ExplorerPatcher.reg"
    if (!(Test-Path $reg)) { throw "ExplorerPatcher.reg not in bundle" }
    $exit = (Start-Process reg -ArgumentList "import `"$reg`"" -Wait -PassThru).ExitCode
    if ($exit -ne 0) { throw "reg import exited $exit" }
}

# 3. Open Shell -- registry import
Step "Restore Open Shell registry" {
    $reg = "$SettingsDir\openshell\OpenShell.reg"
    if (!(Test-Path $reg)) { throw "OpenShell.reg not in bundle" }
    $exit = (Start-Process reg -ArgumentList "import `"$reg`"" -Wait -PassThru).ExitCode
    if ($exit -ne 0) { throw "reg import exited $exit" }
}

# 4. Core Temp -- INI file
Step "Restore CoreTemp.ini" {
    $dst = "C:\Program Files\Core Temp\CoreTemp.ini"
    $src = "$SettingsDir\coretemp\CoreTemp.ini"
    if (!(Test-Path $src)) { throw "CoreTemp.ini not in bundle" }
    if (!(Test-Path "C:\Program Files\Core Temp")) {
        throw "Core Temp not installed yet (run without -SkipInstallers first)"
    }
    Copy-Item $src $dst -Force
}

# 5. Macrium Reflect -- registry import
Step "Restore Macrium Reflect registry (HKCU)" {
    $reg = "$SettingsDir\macrium\Macrium-HKCU.reg"
    if (!(Test-Path $reg)) { throw "Macrium-HKCU.reg not in bundle" }
    $exit = (Start-Process reg -ArgumentList "import `"$reg`"" -Wait -PassThru).ExitCode
    if ($exit -ne 0) { throw "reg import HKCU exited $exit" }
}

Step "Restore Macrium Reflect registry (HKLM)" {
    $reg = "$SettingsDir\macrium\Macrium-HKLM.reg"
    if (!(Test-Path $reg)) { throw "Macrium-HKLM.reg not in bundle" }
    $exit = (Start-Process reg -ArgumentList "import `"$reg`"" -Wait -PassThru).ExitCode
    if ($exit -ne 0) { throw "reg import HKLM exited $exit" }
}

Step "Macrium -- suppress update check (set LastCheck far future)" {
    # v7 update servers went offline Jan 2024. Setting LastCheck=20991231 prevents
    # any auto-check attempt on startup. Value is stored as decimal date (YYYYMMDD).
    $key = "HKCU:\Software\Macrium\Reflect\Defaults"
    if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name "LastCheck" -Value 20991231 -Type DWord
}

# -- Summary --------------------------------------------------------------------
Write-Host ""
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host "  Done: $($ok.Count) steps passed" -ForegroundColor Green
if ($err.Count -gt 0) {
    Write-Host "  FAILED: $($err.Count) step(s):" -ForegroundColor Red
    $err | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}
if ($rebootNeeded) {
    Write-Host ""
    Write-Host "  REBOOT REQUIRED -- ExplorerPatcher replaces the Windows shell." -ForegroundColor Yellow
    Write-Host "  Reboot to apply all shell changes." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Manual steps after reboot:" -ForegroundColor DarkGray
Write-Host "    - 8GadgetPack: right-click desktop -> Gadgets, enable sidebar" -ForegroundColor DarkGray
Write-Host "    - Macrium: verify license key in Help > About" -ForegroundColor DarkGray
Write-Host "    - Macrium: recreate any scheduled backup jobs (not captured by this bundle)" -ForegroundColor DarkGray
Write-Host ""
