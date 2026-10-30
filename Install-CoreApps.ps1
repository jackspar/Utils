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

function Get-MachineContext {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs.Manufacturer -like "*VMware*")    { return "VMware" }
    if ($cs.Manufacturer -like "*VirtualBox*") { return "VirtualBox" }
    if ($cs.Manufacturer -like "*Microsoft*" -and $cs.Model -like "*Virtual*") { return "HyperV" }
    return "BareMetal"
}

$machineContext = Get-MachineContext
$isVM = ($machineContext -ne "BareMetal")

Write-Host ""
Write-Host "  CoreApps Installer  --  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "  Bundle:  $BundleRoot" -ForegroundColor DarkGray
Write-Host "  Machine: $machineContext$(if ($isVM) { ' -- VM mode: Core Temp + Macrium skipped' })" -ForegroundColor $(if ($isVM) { 'Yellow' } else { 'DarkGray' })
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

    # 3. Open Shell -- standalone NSIS installer (offline-capable; Ninite requires internet)
    Step "Install Open Shell (standalone)" {
        # Prefer the standalone OpenShellSetup_*.exe; reject any Ninite wrapper in this context
        $exe = Get-ChildItem "$InstDir\openshell\OpenShellSetup*.exe" |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (!$exe) {
            # Fallback: accept anything in folder but warn about Ninite
            $exe = Get-ChildItem "$InstDir\openshell\*.exe" | Select-Object -First 1
            if (!$exe) { throw "No Open Shell installer found in $InstDir\openshell\" }
            if ($exe.Name -like "*Ninite*") {
                Write-Warning "Using Ninite wrapper -- requires internet. Replace with standalone OpenShellSetup_*.exe for offline use."
            }
        }
        # NSIS silent flag
        $exit = (Start-Process $exe.FullName -ArgumentList "/S" -Wait -PassThru).ExitCode
        if ($exit -ne 0) { Write-Warning "Open Shell installer exited $exit (may still have installed OK)" }
    }

    # 4. Core Temp -- NSIS installer (bare metal only; no physical sensors in a VM)
    if ($isVM) {
        Write-Host "  Install Core Temp -- SKIPPED (VM: no physical CPU sensors)" -ForegroundColor DarkGray
    } else {
        Step "Install Core Temp v1.18.1" {
            $exe = Get-ChildItem "$InstDir\coretemp\*.exe" | Select-Object -First 1
            if (!$exe) { throw "Core Temp installer not found in $InstDir\coretemp\" }
            $exit = (Start-Process $exe.FullName -ArgumentList "/S" -Wait -PassThru).ExitCode
            if ($exit -ne 0) { throw "Core Temp installer exited $exit" }
        }
    }

    # 5. Macrium Reflect -- InnoSetup silent flags (bare metal only; Fusion snapshots handle backup)
    if ($isVM) {
        Write-Host "  Install Macrium Reflect -- SKIPPED (VM: use hypervisor snapshots for backup)" -ForegroundColor DarkGray
    } else {
        Step "Install Macrium Reflect v$MacriumVersion" {
            $pattern = if ($MacriumVersion -eq 7) { "*v7*" } else { "*v8*" }
            $exe = Get-ChildItem "$InstDir\macrium\$pattern" | Select-Object -First 1
            if (!$exe) { throw "Macrium v$MacriumVersion installer not found in $InstDir\macrium\" }
            $exit = (Start-Process $exe.FullName -ArgumentList "/verysilent /norestart" -Wait -PassThru).ExitCode
            if ($exit -ne 0) { throw "Macrium installer exited $exit" }
        }
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

# 3. Open Shell -- import XML settings (primary) + registry (supplementary)
Step "Restore Open Shell settings (XML import)" {
    # XML is the officially supported portable format. Imported via StartMenu.exe -xml.
    # This covers all user-visible settings (style, skin, behavior options).
    $xml = "$SettingsDir\openshell\OpenShell.xml"
    $startMenu = "C:\Program Files\Open-Shell\StartMenu.exe"
    if (!(Test-Path $xml)) { throw "OpenShell.xml not in bundle" }
    if (!(Test-Path $startMenu)) { throw "Open Shell not installed yet (run without -SkipInstallers first)" }
    $exit = (Start-Process $startMenu -ArgumentList "-xml `"$xml`"" -Wait -PassThru).ExitCode
    if ($exit -ne 0) { Write-Warning "StartMenu.exe -xml exited $exit (settings may still have applied)" }
}

Step "Restore Open Shell registry (supplementary)" {
    # Registry export captures the full binary state including binary blobs.
    # Applied after XML so XML wins on any overlap.
    $reg = "$SettingsDir\openshell\OpenShell.reg"
    if (!(Test-Path $reg)) { Write-Warning "OpenShell.reg not in bundle -- skipping supplementary restore"; return }
    $exit = (Start-Process reg -ArgumentList "import `"$reg`"" -Wait -PassThru).ExitCode
    if ($exit -ne 0) { Write-Warning "reg import exited $exit" }
}

# 4. Core Temp -- INI file (bare metal only)
if ($isVM) {
    Write-Host "  Restore CoreTemp.ini -- SKIPPED (VM)" -ForegroundColor DarkGray
} else {
    Step "Restore CoreTemp.ini" {
        $dst = "C:\Program Files\Core Temp\CoreTemp.ini"
        $src = "$SettingsDir\coretemp\CoreTemp.ini"
        if (!(Test-Path $src)) { throw "CoreTemp.ini not in bundle" }
        if (!(Test-Path "C:\Program Files\Core Temp")) {
            throw "Core Temp not installed yet (run without -SkipInstallers first)"
        }
        Copy-Item $src $dst -Force
    }
}

# 5. Macrium Reflect -- registry import (bare metal only)
if ($isVM) {
    Write-Host "  Restore Macrium Reflect -- SKIPPED (VM)" -ForegroundColor DarkGray
} else {
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
    Write-Host "    - 8GadgetPack: gadget positions restore at absolute pixel coords from source machine." -ForegroundColor DarkGray
    Write-Host "                  If monitor layout differs, drag gadgets to correct positions." -ForegroundColor DarkGray
Write-Host "    - Macrium: verify license key in Help > About" -ForegroundColor DarkGray
Write-Host "    - Macrium: recreate any scheduled backup jobs (not captured by this bundle)" -ForegroundColor DarkGray
Write-Host ""
