#Requires -Version 5.1
<#
.SYNOPSIS
    Backs up settings for the 5 JR core apps not on Ninite.
    Output: a CoreApps-Bundle\ folder ready to zip and upload to Fusion.

.NOTES
    Apps: 8GadgetPack v31, ExplorerPatcher, Open Shell, Core Temp, Macrium Reflect v7
    Run on BeeSER (or any source machine) to capture current settings.
    Companion: Install-CoreApps.ps1 (restores on new machine)
#>

$ErrorActionPreference = 'Stop'

# -- Output folder --------------------------------------------------------------
$BundleRoot = Join-Path $PSScriptRoot "CoreApps-Bundle"
$SettingsOut = Join-Path $BundleRoot "settings"
$InstOut     = Join-Path $BundleRoot "installers"

foreach ($d in $BundleRoot, $SettingsOut, $InstOut,
         "$SettingsOut\8gadgetpack",
         "$SettingsOut\explorerpatcher",
         "$SettingsOut\openshell",
         "$SettingsOut\coretemp",
         "$SettingsOut\macrium",
         "$InstOut\8gadgetpack",
         "$InstOut\explorerpatcher",
         "$InstOut\openshell",
         "$InstOut\coretemp",
         "$InstOut\macrium") {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

$ok  = [System.Collections.Generic.List[string]]::new()
$err = [System.Collections.Generic.List[string]]::new()

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

Write-Host ""
Write-Host "  CoreApps Backup  --  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "  Output: $BundleRoot" -ForegroundColor DarkGray
Write-Host ""

# -- 1. 8GadgetPack -------------------------------------------------------------
$SidebarDir = "$env:LOCALAPPDATA\Microsoft\Windows Sidebar"

Step "8GadgetPack -- settings.ini" {
    $src = "$SidebarDir\settings.ini"
    if (!(Test-Path $src)) { throw "settings.ini not found at $src" }
    Copy-Item $src "$SettingsOut\8gadgetpack\settings.ini" -Force
}

Step "8GadgetPack -- Gadgets library (zip)" {
    $gadgetsDir = "$SidebarDir\Gadgets"
    if (!(Test-Path $gadgetsDir)) { throw "Gadgets folder not found at $gadgetsDir" }
    $zip = "$SettingsOut\8gadgetpack\Gadgets.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($gadgetsDir, $zip)
}

Step "8GadgetPack -- stage v31 MSI installer" {
    $candidates = @(
        "D:\OneDrive\w10 to w11 migration\8GadgetPack\8GadgetPackSetup.msi",
        "D:\OneDrive\Downloads\8GadgetPackSetup.msi"
    )
    $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$src) { throw "v31 MSI not found on D:" }
    Copy-Item $src "$InstOut\8gadgetpack\8GadgetPackSetup-v31.msi" -Force
}

# -- 2. ExplorerPatcher ---------------------------------------------------------
Step "ExplorerPatcher -- registry export" {
    $regKey = "HKCU\Software\ExplorerPatcher"
    $out    = "$SettingsOut\explorerpatcher\ExplorerPatcher.reg"
    $result = reg export $regKey $out /y 2>&1
    if ($LASTEXITCODE -ne 0) { throw "reg export failed: $result" }
}

Step "ExplorerPatcher -- stage installer (ep_setup.exe)" {
    # Prefer the w10-to-w11 migration folder (curated); fall back to Downloads
    $candidates = @(
        "D:\OneDrive\w10 to w11 migration\Explorer Patcher\ep_setup.exe",
        "D:\OneDrive\Downloads\Explorer Patcher\ep_setup.exe"
    )
    $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$src) { throw "ep_setup.exe not found on D:" }
    $ver = (Get-Item $src).LastWriteTime.ToString('yyyy-MM-dd')
    Copy-Item $src "$InstOut\explorerpatcher\ep_setup-$ver.exe" -Force
}

# -- 3. Open Shell --------------------------------------------------------------
Step "Open Shell -- registry export" {
    $regKey = "HKCU\Software\OpenShell"
    $out    = "$SettingsOut\openshell\OpenShell.reg"
    $result = reg export $regKey $out /y 2>&1
    if ($LASTEXITCODE -ne 0) { throw "reg export failed: $result" }
}

Step "Open Shell -- stage installer" {
    $candidates = @(
        "D:\OneDrive\w10 to w11 migration\Open Shell\Ninite OpenShell Installer.exe"
    )
    $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$src) { throw "Open Shell installer not found on D:" }
    Copy-Item $src "$InstOut\openshell\NiniteOpenShell-Installer.exe" -Force
}

# -- 4. Core Temp ---------------------------------------------------------------
Step "Core Temp -- CoreTemp.ini" {
    $src = "C:\Program Files\Core Temp\CoreTemp.ini"
    if (!(Test-Path $src)) { throw "CoreTemp.ini not found at $src" }
    Copy-Item $src "$SettingsOut\coretemp\CoreTemp.ini" -Force
}

Step "Core Temp -- stage installer" {
    $candidates = @(
        "D:\OneDrive\w10 to w11 migration\CoreTemp\Core-Temp-setup-v1.18.1.0.exe",
        "D:\OneDrive\Downloads\Core-Temp-setup-v1.18.1.0.exe"
    )
    $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$src) { throw "Core Temp installer not found on D:" }
    Copy-Item $src "$InstOut\coretemp\$(Split-Path $src -Leaf)" -Force
}

# -- 5. Macrium Reflect ---------------------------------------------------------
Step "Macrium Reflect -- HKCU registry export" {
    $regKey = "HKCU\Software\Macrium"
    $out    = "$SettingsOut\macrium\Macrium-HKCU.reg"
    $result = reg export $regKey $out /y 2>&1
    if ($LASTEXITCODE -ne 0) { throw "reg export HKCU failed: $result" }
}

Step "Macrium Reflect -- HKLM registry export" {
    $regKey = "HKLM\Software\Macrium"
    $out    = "$SettingsOut\macrium\Macrium-HKLM.reg"
    $result = reg export $regKey $out /y 2>&1
    if ($LASTEXITCODE -ne 0) { throw "reg export HKLM failed: $result" }
}

Step "Macrium Reflect -- stage v7 installer" {
    # Prefer exact-version MSI from Windows Installer cache (always present on BeeSER after install)
    $cacheMatch = Get-ChildItem "C:\Windows\Installer" -Filter "reflect_setup*x64*.msi" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($cacheMatch) {
        $destName = "reflect-$($cacheMatch.BaseName -replace 'reflect_setup','').msi" -replace '--','-'
        Copy-Item $cacheMatch.FullName "$InstOut\macrium\$destName" -Force
        return
    }
    # Fallback: look in Downloads for any v7 installer
    $candidates = @(
        "D:\OneDrive\Downloads\Macrium Reflect v7.2.4539\v7.2.4539_reflect_setup_free_x64.exe",
        "D:\OneDrive\w10 to w11 migration\Macrium\reflect_setup_free_x64.exe"
    )
    $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$src) { throw "Macrium v7 installer not found in Windows Installer cache or Downloads" }
    Copy-Item $src "$InstOut\macrium\$(Split-Path $src -Leaf)" -Force
}


# NOTE: Macrium backup JOB DEFINITIONS (scheduled backup plans) are stored as
# XML files. Check Macrium Reflect > Other Tasks > Edit Defaults for the
# backup definitions folder, then copy those manually if needed.

# -- Manifest -------------------------------------------------------------------
Step "Write manifest" {
    $reg = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $all = $reg | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue }
    function GetVer($name) {
        ($all | Where-Object { $_.DisplayName -like "*$name*" } |
            Select-Object -First 1).DisplayVersion
    }
    $lines = @(
        "# CoreApps Bundle Manifest",
        "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') on $env:COMPUTERNAME",
        "",
        "## Captured Settings",
        "| App             | Installed Version | Settings Location                                              |",
        "|-----------------|-------------------|----------------------------------------------------------------|",
        "| 8GadgetPack     | $(GetVer '8GadgetPack')            | %LOCALAPPDATA%\Microsoft\Windows Sidebar\settings.ini + Gadgets\ |",
        "| ExplorerPatcher | $(GetVer 'ExplorerPatcher') | HKCU\Software\ExplorerPatcher                                  |",
        "| Open Shell      | $(GetVer 'Open-Shell')              | HKCU\Software\OpenShell                                        |",
        "| Core Temp       | $(GetVer 'Core Temp')            | C:\Program Files\Core Temp\CoreTemp.ini                        |",
        "| Macrium Reflect | $(GetVer 'Macrium Reflect')             | HKCU\Software\Macrium + HKLM\Software\Macrium                  |",
        "",
        "## Version Research Notes",
        "- **8GadgetPack**: v31 bundled. v38+ (now GadgetPack at gadgetpack.net) is same original developer -- safe to upgrade. v43 is current Sep 2026. Pure additions, nothing removed.",
        "- **Macrium Reflect**: v7.2.4539 bundled. STAY ON v7. v8 removed file/folder backup, incremental images, Image Guardian, dark mode, and is EOL (no patches since Jan 2024). v9 = subscription-only. v7.3 is the last full-featured free version.",
        "- **ExplorerPatcher**: version format is [WinBuild].[EPBuild].[major].[minor]. Installed 26100.8457.70.3 is current. No features removed across versions -- always compatibility additions.",
        "- **Open Shell**: 4.4.198 is current. Actively maintained. No feature removals in 4.4.x series.",
        "- **Core Temp**: STAY ON v1.18.1. v1.20 changed INI format -- a direct settings.ini restore WILL FAIL on v1.20+. Bundle the 1.18.1 installer specifically.",
        "- Restore with: Install-CoreApps.ps1"
    )
    $lines | Out-File "$BundleRoot\MANIFEST.md" -Encoding UTF8
}

# -- Summary --------------------------------------------------------------------
Write-Host ""
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host "  Done: $($ok.Count) steps passed" -ForegroundColor Green
if ($err.Count -gt 0) {
    Write-Host "  FAILED: $($err.Count) step(s):" -ForegroundColor Red
    $err | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}
Write-Host ""
Write-Host "  Bundle: $BundleRoot" -ForegroundColor Cyan
Write-Host "  Zip the CoreApps-Bundle\ folder and upload to Fusion / OneDrive." -ForegroundColor DarkGray
Write-Host ""
