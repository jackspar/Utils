# ============================================================
#  MyApps-Setup.ps1
#  Install JR's standard Windows desktop apps on any PC
#  Derived from: jackspar/zPC-Beelink installed app inventory
#  Run: powershell -ExecutionPolicy Bypass -File MyApps-Setup.ps1
# ============================================================

# Auto-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "MyApps-Setup"

# ---- HELPERS ----

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host "   MYAPPS-SETUP                                       " -ForegroundColor Cyan
    Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm')   |   $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  ====================================================" -ForegroundColor Blue
}

function Write-Section($text) {
    Write-Host ""; Write-Host "  -- $text --" -ForegroundColor Yellow
}

function Install-Winget($id, $label) {
    Write-Host "  Installing $label..." -ForegroundColor Gray
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-Host "  [OK] $label" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $label (exit $LASTEXITCODE) - check manually" -ForegroundColor Yellow
    }
}

function Install-GitHubLatest($repo, $assetFilter, $label) {
    Write-Host "  Downloading $label from GitHub..." -ForegroundColor Gray
    try {
        $rel   = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -ErrorAction Stop
        $asset = $rel.assets | Where-Object { $_.name -like $assetFilter } | Select-Object -First 1
        if (-not $asset) { Write-Host "  [WARN] $label - asset not found" -ForegroundColor Yellow; return }
        $tmp = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -ErrorAction Stop
        Start-Process $tmp -Wait
        Write-Host "  [OK] $label" -ForegroundColor Green
    } catch { Write-Host "  [WARN] $label - $_" -ForegroundColor Yellow }
}

function Install-GadgetPack {
    # 8GadgetPack v31 -- USE LOCAL MSI ONLY. Do NOT upgrade to newer versions.
    # Newer versions may omit gadgets used in current config (MyWeather, TopProcessMonitor, etc.)
    # Installer preserved at: D:\OneDrive\w10 to w11 migration\8GadgetPack\8GadgetPackSetup.msi
    $localMsi = "D:\OneDrive\w10 to w11 migration\8GadgetPack\8GadgetPackSetup.msi"

    if (Test-Path $localMsi) {
        Write-Host "  Installing 8GadgetPack v31 from local copy..." -ForegroundColor Gray
        Start-Process msiexec -ArgumentList "/i `"$localMsi`" /quiet /norestart" -Wait
        Write-Host "  [OK] 8GadgetPack v31 installed" -ForegroundColor Green
        Write-Host "  NOTE: After install, restore gadgets from:" -ForegroundColor DarkGray
        Write-Host "        C:\zPC-Beelink\8GadgetPack-backup\ (settings.ini + manifest)" -ForegroundColor DarkGray
    } else {
        Write-Host "  [FAIL] Local MSI not found at: $localMsi" -ForegroundColor Red
        Write-Host "         Copy 8GadgetPackSetup.msi from your D: drive backup before continuing." -ForegroundColor Yellow
        Write-Host "         DO NOT download a newer version -- it may not include your gadgets." -ForegroundColor Yellow
    }
}

# ---- MENU ITEMS ---- (system-verified from zPC-Beelink 2026-10-29)
$apps = @(
    @{ Label = "ExplorerPatcher";  Cat = "Shell/UI";  WingetId = "";                                   Note = "Classic Explorer/taskbar (GitHub)" }
    @{ Label = "Open Shell";       Cat = "Shell/UI";  WingetId = "";                                   Note = "Classic cascading Start Menu (GitHub)" }
    @{ Label = "PowerToys";        Cat = "Shell/UI";  WingetId = "Microsoft.PowerToys";                Note = "Alt+Space, FancyZones, File Explorer add-ons" }
    @{ Label = "8GadgetPack";      Cat = "Shell/UI";  WingetId = "";                                   Note = "Desktop gadgets sidebar (LOCAL MSI ONLY -- v31, no download)" }
    @{ Label = "Brave";            Cat = "Browser";   WingetId = "Brave.Brave";                        Note = "Primary browser" }
    @{ Label = "Firefox";          Cat = "Browser";   WingetId = "Mozilla.Firefox";                    Note = "Secondary + PWAs (Finviz)" }
    @{ Label = "HWiNFO64";         Cat = "Hardware";  WingetId = "REALiX.HWiNFO";                     Note = "CPU/GPU/watts sensors -- enable Shared Memory" }
    @{ Label = "Core Temp";        Cat = "Hardware";  WingetId = "ALTEMPLtd.CoreTemp";                 Note = "Lightweight CPU temp per-core" }
    @{ Label = "CPU-Z";            Cat = "Hardware";  WingetId = "CPUID.CPU-Z";                        Note = "CPU/RAM hardware info" }
    @{ Label = "CrystalDiskMark";  Cat = "Hardware";  WingetId = "CrystalDewWorld.CrystalDiskMark";   Note = "Disk speed benchmark" }
    @{ Label = "Everything";       Cat = "File/Disk"; WingetId = "voidtools.Everything";               Note = "Instant filename search" }
    @{ Label = "WizTree";          Cat = "File/Disk"; WingetId = "AntibodySoftware.WizTree";           Note = "Visual disk space treemap (fast)" }
    @{ Label = "WinDirStat";       Cat = "File/Disk"; WingetId = "WinDirStat.WinDirStat";              Note = "Disk usage color treemap" }
    @{ Label = "7-Zip";            Cat = "File/Disk"; WingetId = "7zip.7zip";                          Note = "Archive manager" }
    @{ Label = "Google Drive";     Cat = "Cloud";     WingetId = "Google.GoogleDrive";                 Note = "Google Drive desktop sync" }
    @{ Label = "VS Code";          Cat = "Dev";       WingetId = "Microsoft.VisualStudioCode";         Note = "Code editor" }
    @{ Label = "Node.js LTS";      Cat = "Dev";       WingetId = "OpenJS.NodeJS.LTS";                  Note = "JS runtime -- required for nt8-mcp server" }
    @{ Label = "Deno";             Cat = "Dev";       WingetId = "DenoLand.Deno";                      Note = "Modern JS/TS runtime" }
    @{ Label = "uv";               Cat = "Dev";       WingetId = "astral-sh.uv";                       Note = "Python package manager" }
    @{ Label = "git";              Cat = "Dev";       WingetId = "Git.Git";                            Note = "Version control" }
    @{ Label = "gh CLI";           Cat = "Dev";       WingetId = "GitHub.cli";                         Note = "GitHub CLI" }
    @{ Label = "OBS Studio";       Cat = "Media";     WingetId = "OBSProject.OBSStudio";               Note = "Screen recording / streaming" }
    @{ Label = "Audacity";         Cat = "Media";     WingetId = "Audacity.Audacity";                  Note = "Audio editor" }
    @{ Label = "FFmpeg";           Cat = "Media";     WingetId = "Gyan.FFmpeg";                        Note = "Video/audio processing CLI" }
    @{ Label = "yt-dlp";           Cat = "Media";     WingetId = "yt-dlp.yt-dlp";                      Note = "Video downloader CLI" }
    @{ Label = "Foxit PDF";        Cat = "Media";     WingetId = "Foxit.FoxitReader";                  Note = "PDF reader" }
    @{ Label = "Macrium Reflect";  Cat = "Utility";   WingetId = "Macrium.Reflect.Free";               Note = "Disk imaging / backup" }
    @{ Label = "Wise Uninstaller"; Cat = "Utility";   WingetId = "WiseCleaner.WiseProgramUninstaller"; Note = "Preferred uninstaller" }
    @{ Label = "Zoom";             Cat = "Utility";   WingetId = "Zoom.Zoom";                          Note = "Video conferencing" }
    @{ Label = "Messenger";        Cat = "Utility";   WingetId = "Meta.Messenger";                     Note = "Facebook Messenger desktop" }
    @{ Label = "GeForce NOW";      Cat = "Gaming";    WingetId = "Nvidia.GeForceNow";                  Note = "Cloud gaming" }
    @{ Label = "Steam";            Cat = "Gaming";    WingetId = "Valve.Steam";                        Note = "Steam gaming client" }
    @{ Label = "Epic Games";       Cat = "Gaming";    WingetId = "EpicGames.EpicGamesLauncher";        Note = "Epic Games store" }
    @{ Label = "Canva";            Cat = "App";       WingetId = "Canva.Canva";                        Note = "Design tool" }
)

$total = $apps.Count

# ---- NEVER CONFIG ----
$neverFile = Join-Path $env:APPDATA "MyApps-Setup\never.txt"
$neverDir  = Split-Path $neverFile -Parent

function Read-NeverList {
    if (Test-Path $neverFile) {
        return @(Get-Content $neverFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    }
    return @()
}

function Write-NeverList($labels) {
    if (-not (Test-Path $neverDir)) { New-Item -ItemType Directory -Path $neverDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($neverFile, ($labels -join "`n"), [System.Text.UTF8Encoding]::new($false))
}

# ---- INSTALLED SCAN ----
Write-Host ""
Write-Host "  Scanning installed apps..." -ForegroundColor DarkGray
$wingetRaw = ""
if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
        $wingetLines = (winget list 2>&1) | ForEach-Object { $_.ToString() } |
            Where-Object { $_ -match '\S{4,}' -and $_ -notmatch '^[\s\\|/\-]+$' }
        $wingetRaw = $wingetLines -join "`n"
    } catch { $wingetRaw = "" }
}

for ($x = 0; $x -lt $apps.Count; $x++) {
    $wid = $apps[$x].WingetId
    $inst = $false; $upd = $false
    if ($wid -and $wingetRaw) {
        $pat  = [regex]::Escape($wid)
        $line = ($wingetRaw -split "`n" | Where-Object { $_ -match $pat } | Select-Object -First 1)
        if ($line) {
            $inst  = $true
            $parts = @($line.TrimEnd() -split '\s{2,}' | Where-Object { $_ -ne "" })
            # winget list columns: Name, Id, Version, Available, Source
            # Available is only populated when an upgrade exists
            if ($parts.Count -ge 4 -and $parts[3] -match '^\d') { $upd = $true }
        }
    }
    $apps[$x].IsInst = $inst
    $apps[$x].HasUpd = $upd
}

# ---- INIT STATES ----
# State: 0=[ ] skip  1=[X] install  2=[!] NEVER
$neverList = Read-NeverList
$states = @(0..($total - 1) | ForEach-Object {
    $lbl = $apps[$_].Label
    if ($lbl -eq "8GadgetPack")         { 2 }
    elseif ($neverList -contains $lbl)  { 2 }
    else                                { 1 }
})

# ---- SHOW MENU ----
function Show-Menu($states, $cursor) {
    Write-Banner
    Write-Host "  UP/DOWN=move  SPACE=cycle([ ]/[X]/[!])  A=all  N=none  ENTER=install  Q=quit" -ForegroundColor Yellow
    Write-Host "  [ ]=skip  [X]=install  [!]=NEVER  +=installed  ^=update avail" -ForegroundColor DarkGray
    Write-Host ""

    $catStart = 0
    while ($catStart -lt $apps.Count) {
        $cat    = $apps[$catStart].Cat
        $catEnd = $catStart
        while ($catEnd -lt $apps.Count -and $apps[$catEnd].Cat -eq $cat) { $catEnd++ }

        Write-Host ("  [ {0} ]" -f $cat) -ForegroundColor DarkCyan

        $ci = $catStart
        while ($ci -lt $catEnd) {
            # Collect up to 3 indices for this row
            $row = @()
            for ($c = 0; $c -lt 3 -and ($ci + $c) -lt $catEnd; $c++) {
                $row += ($ci + $c)
            }

            for ($c = 0; $c -lt $row.Count; $c++) {
                $idx    = $row[$c]
                $st     = $states[$idx]
                $isCur  = ($idx -eq $cursor)
                $prefix = if ($isCur) { ">>" } else { "  " }
                $chk    = if ($st -eq 1) { "[X]" } elseif ($st -eq 2) { "[!]" } else { "[ ]" }
                $color  = if ($isCur) { "Cyan" } elseif ($st -eq 1) { "Green" } elseif ($st -eq 2) { "DarkRed" } else { "DarkGray" }

                $marker = " "
                if     ($apps[$idx].HasUpd)  { $marker = "^" }
                elseif ($apps[$idx].IsInst)  { $marker = "+" }

                $name = $apps[$idx].Label.TrimEnd()
                if ($name.Length -gt 13) { $name = $name.Substring(0, 13) }
                $name = $name.PadRight(13)

                # Slot width: prefix(2)+chk(3)+sp(1)+num(3)+sp(1)+name(13)+marker(1) = 24 chars
                $slot   = "{0}{1} {2,2}. {3}{4}" -f $prefix, $chk, ($idx + 1), $name, $marker
                $isLast = ($c -eq ($row.Count - 1))

                if ($isLast) {
                    Write-Host $slot -ForegroundColor $color
                } else {
                    Write-Host $slot -ForegroundColor $color -NoNewline
                }
            }

            $ci += 3
        }
        Write-Host ""
        $catStart = $catEnd
    }

    Write-Host "  MANUAL: NinjaTrader 8  |  thinkorswim  |  Office 2010  |  Epson Scan 2" -ForegroundColor DarkGray
    Write-Host ""
}

# ---- INPUT LOOP ----
$cursor = 0

while ($true) {
    Show-Menu $states $cursor
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $ch  = $key.Character.ToString().ToUpper()
    $vk  = $key.VirtualKeyCode

    if ($vk -eq 38) {
        if ($cursor -gt 0) { $cursor-- }
    } elseif ($vk -eq 40) {
        if ($cursor -lt ($total - 1)) { $cursor++ }
    } elseif ($vk -eq 32) {
        $oldState = $states[$cursor]
        $newState = ($oldState + 1) % 3
        $states[$cursor] = $newState
        # Sync NEVER list (8GadgetPack hardcoded to start [!] but user can still cycle)
        $lbl  = $apps[$cursor].Label
        $list = @(Read-NeverList)
        if ($newState -eq 2) {
            if ($list -notcontains $lbl) { Write-NeverList ($list + $lbl) }
        } else {
            $filtered = @($list | Where-Object { $_ -ne $lbl })
            if ($filtered.Count -ne $list.Count) { Write-NeverList $filtered }
        }
    } elseif ($vk -eq 13) {
        break
    } elseif ($ch -eq "Q") {
        exit
    } elseif ($ch -eq "A") {
        for ($k = 0; $k -lt $total; $k++) {
            if ($states[$k] -ne 2) { $states[$k] = 1 }
        }
    } elseif ($ch -eq "N") {
        for ($k = 0; $k -lt $total; $k++) {
            if ($states[$k] -ne 2) { $states[$k] = 0 }
        }
    }
}

# ---- INSTALL ----
Write-Banner
Write-Host ""
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  [ERROR] winget not found. Install 'App Installer' from Microsoft Store." -ForegroundColor Red
    Read-Host "  Press Enter to exit"; exit 1
}
Write-Host "  Starting installs..." -ForegroundColor Yellow

$i = 0
# Shell/UI
if ($states[$i] -eq 1) { Write-Section "ExplorerPatcher";    Install-GitHubLatest "valinet/ExplorerPatcher" "ep_setup.exe" "ExplorerPatcher" };          $i++
if ($states[$i] -eq 1) { Write-Section "Open Shell";         Install-GitHubLatest "Open-Shell/Open-Shell-Menu" "OpenShellSetup_*.exe" "Open Shell" };    $i++
if ($states[$i] -eq 1) { Write-Section "PowerToys";          Install-Winget "Microsoft.PowerToys" "PowerToys" };                                         $i++
if ($states[$i] -eq 1) { Write-Section "8GadgetPack";        Install-GadgetPack };                                                                       $i++
# Browsers
if ($states[$i] -eq 1) { Write-Section "Brave";              Install-Winget "Brave.Brave" "Brave Browser" };                                             $i++
if ($states[$i] -eq 1) { Write-Section "Firefox";            Install-Winget "Mozilla.Firefox" "Firefox" };                                               $i++
# Hardware
if ($states[$i] -eq 1) { Write-Section "HWiNFO";             Install-Winget "REALiX.HWiNFO" "HWiNFO 64" };                                              $i++
if ($states[$i] -eq 1) { Write-Section "Core Temp";          Install-Winget "ALTEMPLtd.CoreTemp" "Core Temp" };                                          $i++
if ($states[$i] -eq 1) { Write-Section "CPU-Z";              Install-Winget "CPUID.CPU-Z" "CPU-Z" };                                                     $i++
if ($states[$i] -eq 1) { Write-Section "CrystalDiskMark";    Install-Winget "CrystalDewWorld.CrystalDiskMark" "CrystalDiskMark" };                       $i++
# File/Disk
if ($states[$i] -eq 1) { Write-Section "Everything";         Install-Winget "voidtools.Everything" "Everything" };                                       $i++
if ($states[$i] -eq 1) { Write-Section "WizTree";            Install-Winget "AntibodySoftware.WizTree" "WizTree" };                                      $i++
if ($states[$i] -eq 1) { Write-Section "WinDirStat";         Install-Winget "WinDirStat.WinDirStat" "WinDirStat" };                                      $i++
if ($states[$i] -eq 1) { Write-Section "7-Zip";              Install-Winget "7zip.7zip" "7-Zip" };                                                       $i++
# Cloud
if ($states[$i] -eq 1) { Write-Section "Google Drive";       Install-Winget "Google.GoogleDrive" "Google Drive" };                                       $i++
# Dev
if ($states[$i] -eq 1) { Write-Section "VS Code";            Install-Winget "Microsoft.VisualStudioCode" "VS Code" };                                    $i++
if ($states[$i] -eq 1) { Write-Section "Node.js LTS";        Install-Winget "OpenJS.NodeJS.LTS" "Node.js LTS" };                                         $i++
if ($states[$i] -eq 1) { Write-Section "Deno";               Install-Winget "DenoLand.Deno" "Deno" };                                                    $i++
if ($states[$i] -eq 1) { Write-Section "uv";                 Install-Winget "astral-sh.uv" "uv" };                                                       $i++
if ($states[$i] -eq 1) { Write-Section "git";                Install-Winget "Git.Git" "Git" };                                                           $i++
if ($states[$i] -eq 1) { Write-Section "gh CLI";             Install-Winget "GitHub.cli" "gh CLI" };                                                     $i++
# Media
if ($states[$i] -eq 1) { Write-Section "OBS Studio";         Install-Winget "OBSProject.OBSStudio" "OBS Studio" };                                       $i++
if ($states[$i] -eq 1) { Write-Section "Audacity";           Install-Winget "Audacity.Audacity" "Audacity" };                                            $i++
if ($states[$i] -eq 1) { Write-Section "FFmpeg";             Install-Winget "Gyan.FFmpeg" "FFmpeg" };                                                    $i++
if ($states[$i] -eq 1) { Write-Section "yt-dlp";             Install-Winget "yt-dlp.yt-dlp" "yt-dlp" };                                                  $i++
if ($states[$i] -eq 1) { Write-Section "Foxit PDF Reader";   Install-Winget "Foxit.FoxitReader" "Foxit PDF Reader" };                                    $i++
# Utilities
if ($states[$i] -eq 1) { Write-Section "Macrium Reflect";    Install-Winget "Macrium.Reflect.Free" "Macrium Reflect Free" };                             $i++
if ($states[$i] -eq 1) { Write-Section "Wise Uninstaller";   Install-Winget "WiseCleaner.WiseProgramUninstaller" "Wise Program Uninstaller" };           $i++
if ($states[$i] -eq 1) { Write-Section "Zoom";               Install-Winget "Zoom.Zoom" "Zoom" };                                                        $i++
if ($states[$i] -eq 1) { Write-Section "Messenger";          Install-Winget "Meta.Messenger" "Messenger" };                                              $i++
# Gaming
if ($states[$i] -eq 1) { Write-Section "GeForce NOW";        Install-Winget "Nvidia.GeForceNow" "NVIDIA GeForce NOW" };                                  $i++
if ($states[$i] -eq 1) { Write-Section "Steam";              Install-Winget "Valve.Steam" "Steam" };                                                     $i++
if ($states[$i] -eq 1) { Write-Section "Epic Games";         Install-Winget "EpicGames.EpicGamesLauncher" "Epic Games Launcher" };                       $i++
# Apps
if ($states[$i] -eq 1) { Write-Section "Canva";              Install-Winget "Canva.Canva" "Canva" };                                                     $i++

# ---- DONE ----
Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host "   INSTALL COMPLETE                                   " -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host ""
Write-Host "  Post-install steps:" -ForegroundColor Yellow
Write-Host "    1. ExplorerPatcher: Properties > Restart File Explorer" -ForegroundColor White
Write-Host "    2. Open Shell: set Classic style, create My Utilities folder" -ForegroundColor White
Write-Host "    3. HWiNFO: Settings > Shared Memory Support (ON)" -ForegroundColor White
Write-Host "       Required for 8GadgetPack to read CPU temp/watts sensors" -ForegroundColor DarkGray
Write-Host "    4. Add Brave + 8GadgetPack to Startup folder" -ForegroundColor White
Write-Host "    5. Set execution policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
Write-Host ""
Write-Host "  Manual installs still needed:" -ForegroundColor Yellow
Write-Host "    NinjaTrader 8 / thinkorswim / Office 2010 / Epson Scan 2" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to close"
