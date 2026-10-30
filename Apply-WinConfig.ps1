#Requires -Version 5.1
<#
.SYNOPSIS
    Applies JR standard Windows configuration.
    Run as Administrator BEFORE enabling network on a new machine or Fusion VM.

.PARAMETER SkipDotNet
    Skip .NET 3.5 DISM step (requires Windows source files or internet).

.NOTES
    SKIP ALWAYS: Activity History (Win+R history), OneDrive, Services-to-Manual,
                 IPv6 (verify broker connectivity first), NTP (fix Ryzen C-states first).
#>
param(
    [switch]$SkipDotNet
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Warning "Not running as Administrator. Registry edits to HKLM will fail."
    Write-Warning "Right-click PowerShell -> Run as Administrator"
    Write-Host ""
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

function EnsureKey($path) {
    if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
}

$build   = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
$isWin11 = ($build -ge 22000)
$isArm64 = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
$cs      = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$isVM    = $cs.Manufacturer -like "*VMware*" -or
           $cs.Manufacturer -like "*VirtualBox*" -or
           ($cs.Manufacturer -like "*Microsoft*" -and $cs.Model -like "*Virtual*")

Write-Host ""
Write-Host "  Apply-WinConfig  --  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "  Machine: $env:COMPUTERNAME  $(if ($isVM) { '(VM -- .NET 3.5 skipped)' })" -ForegroundColor $(if ($isVM) { 'Yellow' } else { 'DarkGray' })
Write-Host "  OS:      $(if ($isWin11) { 'Windows 11' } else { 'Windows 10' }) (build $build)  $(if ($isArm64) { 'ARM64' } else { 'x64' })" -ForegroundColor $(if ($isWin11) { 'Yellow' } else { 'DarkGray' })
Write-Host ""

# -- APPEARANCE ----------------------------------------------------------------

Write-Host "  [ Appearance ]" -ForegroundColor DarkGray

Step "Dark theme -- apps and system" {
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "AppsUseLightTheme"    -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "SystemUsesLightTheme" -Value 0 -Type DWord
}

Step "Desktop -- solid black background" {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper"     -Value "" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\Colors"  -Name "Background"    -Value "0 0 0" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "0" -Type String
}

Step "Explorer -- open to This PC (not Quick Access)" {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "LaunchTo" -Value 1 -Type DWord
}

Step "Explorer -- show file extensions" {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "HideFileExt" -Value 0 -Type DWord
}

Step "Explorer -- show hidden files" {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "Hidden" -Value 1 -Type DWord
}

# -- TASKBAR / SHELL -----------------------------------------------------------

Write-Host ""
Write-Host "  [ Taskbar / Shell ]" -ForegroundColor DarkGray

Step "Taskbar -- move to top (Win10) / left-align (Win11)" {
    if ($isWin11) {
        # Win11 native taskbar can't go to top without EP; set left alignment for now
        # EP's registry restore (Install-CoreApps) will move it to top after reboot
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "TaskbarAl" -Value 0 -Type DWord
    } else {
        $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
        if (Test-Path $key) {
            $val = (Get-ItemProperty $key).Settings
            $val[12] = 1  # ABE_TOP=1; left=0, right=2, bottom=3
            Set-ItemProperty $key Settings $val
        }
    }
}

Step "Taskbar -- hide search box" {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" `
        -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
}

Step "Taskbar -- enable End Task on right-click" {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "TaskbarEndTask" -Value 1 -Type DWord
}

Step "Menu show delay -- 1ms (snappy menus)" {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "1" -Type String
}

# -- PRIVACY / TELEMETRY -------------------------------------------------------

Write-Host ""
Write-Host "  [ Privacy / Telemetry ]" -ForegroundColor DarkGray

Step "Telemetry -- disable (Policy + Direct)" {
    $pol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    $dir = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    EnsureKey $pol; EnsureKey $dir
    Set-ItemProperty -Path $pol -Name "AllowTelemetry" -Value 0 -Type DWord
    Set-ItemProperty -Path $dir -Name "AllowTelemetry" -Value 0 -Type DWord
}

Step "Advertising ID -- disable" {
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "Enabled" -Value 0 -Type DWord
}

Step "Cortana + web search in Start -- disable" {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "AllowCortana"          -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "DisableWebSearch"      -Value 1 -Type DWord
    Set-ItemProperty -Path $path -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord
}

Step "Consumer features -- disable (Candy Crush / MS ads in Start)" {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord
}

Step "Suggested apps in Start -- disable" {
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "SystemPaneSuggestionsEnabled"       -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "SoftLandingEnabled"                 -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "SubscribedContent-338388Enabled"    -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "SubscribedContent-338389Enabled"    -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "SubscribedContent-353696Enabled"    -Value 0 -Type DWord
}

Step "Location tracking -- disable" {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "DisableLocation" -Value 1 -Type DWord
}

# -- NETWORK / POWER -----------------------------------------------------------

Write-Host ""
Write-Host "  [ Network / Power ]" -ForegroundColor DarkGray

Step "Teredo -- disable" {
    $result = netsh interface teredo set state disabled 2>&1
    if ($LASTEXITCODE -ne 0) { throw "netsh exited $LASTEXITCODE`: $result" }
}

Step "Delivery Optimization -- disable P2P (set to Off)" {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "DODownloadMode" -Value 0 -Type DWord
}

Step "Hibernation -- disable" {
    $result = powercfg /hibernate off 2>&1
    if ($LASTEXITCODE -ne 0) { throw "powercfg exited $LASTEXITCODE`: $result" }
}

Step "Background apps (UWP) -- disable globally" {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "GlobalUserDisabled" -Value 1 -Type DWord
}

Step "Storage Sense -- disable" {
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    EnsureKey $path
    Set-ItemProperty -Path $path -Name "01" -Value 0 -Type DWord
}

Step "WPBT -- disable (blocks OEM BIOS-injected software)" {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $path -Name "DisableWpbtExecution" -Value 1 -Type DWord
}

# -- WINDOWS UPDATE ------------------------------------------------------------

Write-Host ""
Write-Host "  [ Windows Update ]" -ForegroundColor DarkGray

Step "Windows Update -- Recommended profile (feature +365d, quality +4d)" {
    $wu   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $wuAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    EnsureKey $wu; EnsureKey $wuAU
    Set-ItemProperty -Path $wu -Name "DeferFeatureUpdates"            -Value 1   -Type DWord
    Set-ItemProperty -Path $wu -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord
    Set-ItemProperty -Path $wu -Name "DeferQualityUpdates"            -Value 1   -Type DWord
    Set-ItemProperty -Path $wu -Name "DeferQualityUpdatesPeriodInDays" -Value 4  -Type DWord
}

# -- POWER PLAN ----------------------------------------------------------------

Write-Host ""
Write-Host "  [ Power Plan ]" -ForegroundColor DarkGray

Step "Power plan -- High Performance, never sleep or dim" {
    # Activate High Performance plan
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
    # Sleep / standby: never (AC + DC)
    powercfg /change standby-timeout-ac   0
    powercfg /change standby-timeout-dc   0
    powercfg /change hibernate-timeout-ac 0
    powercfg /change hibernate-timeout-dc 0
    # Monitor: never turn off
    powercfg /change monitor-timeout-ac   0
    powercfg /change monitor-timeout-dc   0
}

# -- BLOAT REMOVAL -------------------------------------------------------------

Write-Host ""
Write-Host "  [ Bloat Removal ]" -ForegroundColor DarkGray

$bloatPackages = @(
    "Microsoft.BingFinance",
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingSports",
    "Microsoft.Getstarted",
    "Microsoft.GetHelp",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.People",
    "Microsoft.SkypeApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",       # Groove Music
    "Microsoft.ZuneVideo",       # Movies & TV
    "Microsoft.3DBuilder",
    "Microsoft.Paint3D",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.549981C3F5F10",   # Cortana app (newer Win10 builds)
    # Win11 additions (safe to include -- silently skipped if not present on Win10)
    "MicrosoftTeams",            # consumer Teams (Win11 preinstalled)
    "Clipchamp.Clipchamp",       # Clipchamp video editor
    "Microsoft.BingSearch",      # Bing in taskbar search
    "Microsoft.Copilot",         # standalone Copilot app
    "Microsoft.Windows.DevHome", # Dev Home
    "Microsoft.OutlookForWindows" # new Outlook
)

foreach ($pkg in $bloatPackages) {
    Step "Remove $pkg" {
        # Remove for current user
        Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue |
            Remove-AppxPackage -ErrorAction SilentlyContinue
        # Remove provisioned (new user accounts won't get it)
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.PackageName -like "$pkg*" } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

# -- WINDOWS 11 SPECIFIC -------------------------------------------------------

if ($isWin11) {
    Write-Host ""
    Write-Host "  [ Windows 11 ]" -ForegroundColor Yellow

    Step "Win11 -- disable Widgets button" {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "TaskbarDa" -Value 0 -Type DWord
    }

    Step "Win11 -- disable Chat / Teams button" {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "TaskbarMn" -Value 0 -Type DWord
    }

    Step "Win11 -- disable Copilot button" {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "ShowCopilotButton" -Value 0 -Type DWord
    }

    Step "Win11 -- disable Start recommended section" {
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        EnsureKey $path
        Set-ItemProperty -Path $path -Name "HideRecentlyAddedApps"    -Value 1 -Type DWord
        Set-ItemProperty -Path $path -Name "ShowOrHideMostUsedApps"   -Value 2 -Type DWord
    }
}

# -- .NET FRAMEWORK ------------------------------------------------------------

Write-Host ""
Write-Host "  [ .NET Framework ]" -ForegroundColor DarkGray

if ($SkipDotNet -or $isVM) {
    $reason = if ($isVM) { 'VM -- needs Windows ISO or network' } else { '-SkipDotNet' }
    Write-Host "  .NET 3.5 -- SKIPPED ($reason)" -ForegroundColor DarkGray
} else {
    Step ".NET 3.5 + 4.x -- enable via DISM" {
        # Tries online source first; if offline, needs Windows ISO mounted and source path set
        $result = DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ".NET 3.5 DISM failed (exit $LASTEXITCODE). If offline, run:`n  DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:D:\sources\sxs"
        }
    }
}

# -- SUMMARY -------------------------------------------------------------------

Write-Host ""
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host "  Done: $($ok.Count) steps passed" -ForegroundColor Green
if ($err.Count -gt 0) {
    Write-Host "  FAILED: $($err.Count) step(s):" -ForegroundColor Red
    $err | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}
Write-Host ""
Write-Host "  Notes:" -ForegroundColor DarkGray
Write-Host "    - Dark theme and background apply on next logon / Explorer restart" -ForegroundColor DarkGray
Write-Host "    - File extension / hidden file settings: re-open Explorer to see effect" -ForegroundColor DarkGray
Write-Host "    - Run Install-CoreApps.ps1 next to install apps + restore settings" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  SKIP (by design -- do not add):" -ForegroundColor DarkGray
Write-Host "    - Activity History (Win+R Run history depends on it)" -ForegroundColor DarkGray
Write-Host "    - OneDrive (BeeSER production depends on it)" -ForegroundColor DarkGray
Write-Host "    - Visual Effects (user preference -- leave Windows default)" -ForegroundColor DarkGray
Write-Host "    - IPv6 (verify broker API connectivity before disabling)" -ForegroundColor DarkGray
Write-Host "    - NTP (fix Ryzen C-states first -- see CTT-Tweaks-Notes.md)" -ForegroundColor DarkGray
Write-Host ""
