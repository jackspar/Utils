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
    # GadgetPack (formerly 8GadgetPack) — gadgetpack.net
    # Try downloading latest first; fall back to local copy on D:
    $url      = "https://gadgetpack.net/dl_430/GadgetPackSetup.msi"
    $localMsi = "D:\OneDrive\w10 to w11 migration\8GadgetPack\8GadgetPackSetup.msi"
    $tmp      = Join-Path $env:TEMP "GadgetPackSetup.msi"

    Write-Host "  Downloading GadgetPack from gadgetpack.net..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -ErrorAction Stop
        Start-Process msiexec -ArgumentList "/i `"$tmp`" /quiet /norestart" -Wait
        Write-Host "  [OK] GadgetPack v43.0" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Download failed - trying local copy..." -ForegroundColor Yellow
        if (Test-Path $localMsi) {
            Start-Process msiexec -ArgumentList "/i `"$localMsi`" /quiet /norestart" -Wait
            Write-Host "  [OK] GadgetPack (local copy)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] No local copy found. Download manually: gadgetpack.net" -ForegroundColor Red
        }
    }
}

# ---- MENU ITEMS ---- (system-verified from zPC-Beelink 2026-10-29)
$apps = @(
    # Shell / UI
    @{ Label = "ExplorerPatcher         "; Cat = "Shell/UI";    Note = "Classic Explorer/taskbar (GitHub)" }
    @{ Label = "Open Shell              "; Cat = "Shell/UI";    Note = "Classic cascading Start Menu (GitHub)" }
    @{ Label = "Microsoft PowerToys     "; Cat = "Shell/UI";    Note = "Alt+Space, FancyZones, File Explorer add-ons" }
    @{ Label = "GadgetPack              "; Cat = "Shell/UI";    Note = "Desktop gadgets (downloads v43 from gadgetpack.net)" }
    # Browsers
    @{ Label = "Brave Browser           "; Cat = "Browser";     Note = "Primary browser — auto-start, do NOT clear cache" }
    @{ Label = "Firefox                 "; Cat = "Browser";     Note = "Secondary + PWAs (Finviz) — do NOT clear cache" }
    # Hardware Monitoring
    @{ Label = "HWiNFO 64               "; Cat = "Hardware";    Note = "CPU/GPU/watts sensors — enable Shared Memory for gadgets" }
    @{ Label = "Core Temp               "; Cat = "Hardware";    Note = "Lightweight CPU temp per-core" }
    @{ Label = "CPU-Z                   "; Cat = "Hardware";    Note = "CPU/RAM hardware info" }
    @{ Label = "CrystalDiskMark         "; Cat = "Hardware";    Note = "Disk speed benchmark" }
    # File & Disk
    @{ Label = "Everything              "; Cat = "File/Disk";   Note = "Instant filename search" }
    @{ Label = "WizTree                 "; Cat = "File/Disk";   Note = "Visual disk space treemap (fast)" }
    @{ Label = "WinDirStat              "; Cat = "File/Disk";   Note = "Disk usage color treemap" }
    @{ Label = "7-Zip                   "; Cat = "File/Disk";   Note = "Archive manager" }
    # Cloud / Sync
    @{ Label = "Google Drive            "; Cat = "Cloud";       Note = "Google Drive desktop sync" }
    # Dev
    @{ Label = "Visual Studio Code      "; Cat = "Dev";         Note = "Code editor" }
    @{ Label = "Node.js LTS             "; Cat = "Dev";         Note = "JS runtime — required for nt8-mcp server" }
    @{ Label = "Deno                    "; Cat = "Dev";         Note = "Modern JS/TS runtime" }
    @{ Label = "uv                      "; Cat = "Dev";         Note = "Python package manager (fast pip replacement)" }
    @{ Label = "git                     "; Cat = "Dev";         Note = "Version control" }
    @{ Label = "gh CLI                  "; Cat = "Dev";         Note = "GitHub CLI" }
    # Media / Creative
    @{ Label = "OBS Studio              "; Cat = "Media";       Note = "Screen recording / streaming" }
    @{ Label = "Audacity                "; Cat = "Media";       Note = "Audio editor" }
    @{ Label = "FFmpeg                  "; Cat = "Media";       Note = "Video/audio processing CLI" }
    @{ Label = "yt-dlp                  "; Cat = "Media";       Note = "Video downloader CLI" }
    @{ Label = "Foxit PDF Reader        "; Cat = "Media";       Note = "PDF reader" }
    # Utilities
    @{ Label = "Macrium Reflect Free    "; Cat = "Utility";     Note = "Disk imaging / backup" }
    @{ Label = "Wise Program Uninstaller"; Cat = "Utility";     Note = "Preferred uninstaller" }
    @{ Label = "Zoom                    "; Cat = "Utility";     Note = "Video conferencing" }
    @{ Label = "Messenger               "; Cat = "Utility";     Note = "Facebook Messenger desktop" }
    # Gaming
    @{ Label = "NVIDIA GeForce NOW      "; Cat = "Gaming";      Note = "Cloud gaming" }
    @{ Label = "Steam                   "; Cat = "Gaming";      Note = "Steam gaming client" }
    @{ Label = "Epic Games Launcher     "; Cat = "Gaming";      Note = "Epic Games store" }
    # Apps
    @{ Label = "Canva                   "; Cat = "App";         Note = "Design tool" }
)

$total = $apps.Count

# ---- SHOW MENU ----
function Show-Menu($selected) {
    Write-Banner
    Write-Host ""
    Write-Host "  Select apps to install  (number to toggle, ENTER to run, Q to quit)" -ForegroundColor Yellow
    Write-Host "  A = Select All   N = Select None" -ForegroundColor DarkGray
    Write-Host ""

    $lastCat = ""
    for ($i = 0; $i -lt $apps.Count; $i++) {
        if ($apps[$i].Cat -ne $lastCat) {
            Write-Host ("     [ {0} ]" -f $apps[$i].Cat) -ForegroundColor DarkCyan
            $lastCat = $apps[$i].Cat
        }
        $chk = if ($selected[$i]) { "[X]" } else { "[ ]" }
        $col = if ($selected[$i]) { "Green" } else { "DarkGray" }
        Write-Host ("  {0} {1,2}. {2}  {3}" -f $chk, ($i+1), $apps[$i].Label, $apps[$i].Note) -ForegroundColor $col
    }

    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host "  MANUAL ONLY (cannot be automated):" -ForegroundColor DarkGray
    Write-Host "    NinjaTrader 8   ninjatrader.com (requires account)" -ForegroundColor DarkGray
    Write-Host "    thinkorswim     schwab.com/trading/thinkorswim" -ForegroundColor DarkGray
    Write-Host "    Office 2010     from install media" -ForegroundColor DarkGray
    Write-Host "    Epson Scan 2    epson.com (scanner-specific)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("  1-{0} toggle  |  A all  |  N none  |  ENTER install  |  Q quit" -f $total) -ForegroundColor Yellow
    Write-Host ""
}

$selected = @(1..$total | ForEach-Object { $true })

while ($true) {
    Show-Menu $selected
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $ch  = $key.Character.ToString().ToUpper()

    if     ($ch -eq "Q")              { Write-Host "  Cancelled." -ForegroundColor DarkGray; Read-Host "  Press Enter to close"; exit }
    elseif ($key.VirtualKeyCode -eq 13) { break }
    elseif ($ch -eq "A")              { $selected = @(1..$total | ForEach-Object { $true }) }
    elseif ($ch -eq "N")              { $selected = @(1..$total | ForEach-Object { $false }) }
    elseif ($ch -ge "1" -and $ch -le "9") {
        $idx = [int]$ch - 1
        if ($idx -lt $total) { $selected[$idx] = -not $selected[$idx] }
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
if ($selected[$i]) { Write-Section "ExplorerPatcher";    Install-GitHubLatest "valinet/ExplorerPatcher" "ep_setup.exe" "ExplorerPatcher" };                                         $i++
if ($selected[$i]) { Write-Section "Open Shell";         Install-GitHubLatest "Open-Shell/Open-Shell-Menu" "OpenShellSetup_*.exe" "Open Shell" };                                   $i++
if ($selected[$i]) { Write-Section "PowerToys";          Install-Winget "Microsoft.PowerToys" "PowerToys" };                                                                        $i++
if ($selected[$i]) { Write-Section "GadgetPack";         Install-GadgetPack };                                                                                               $i++
# Browsers
if ($selected[$i]) { Write-Section "Brave";              Install-Winget "Brave.Brave" "Brave Browser" };                                                                            $i++
if ($selected[$i]) { Write-Section "Firefox";            Install-Winget "Mozilla.Firefox" "Firefox" };                                                                              $i++
# Hardware
if ($selected[$i]) { Write-Section "HWiNFO";             Install-Winget "REALiX.HWiNFO" "HWiNFO 64" };                                                                             $i++
if ($selected[$i]) { Write-Section "Core Temp";          Install-Winget "ALTEMPLtd.CoreTemp" "Core Temp" };                                                                         $i++
if ($selected[$i]) { Write-Section "CPU-Z";              Install-Winget "CPUID.CPU-Z" "CPU-Z" };                                                                                    $i++
if ($selected[$i]) { Write-Section "CrystalDiskMark";    Install-Winget "CrystalDewWorld.CrystalDiskMark" "CrystalDiskMark" };                                                      $i++
# File/Disk
if ($selected[$i]) { Write-Section "Everything";         Install-Winget "voidtools.Everything" "Everything" };                                                                      $i++
if ($selected[$i]) { Write-Section "WizTree";            Install-Winget "AntibodySoftware.WizTree" "WizTree" };                                                                     $i++
if ($selected[$i]) { Write-Section "WinDirStat";         Install-Winget "WinDirStat.WinDirStat" "WinDirStat" };                                                                     $i++
if ($selected[$i]) { Write-Section "7-Zip";              Install-Winget "7zip.7zip" "7-Zip" };                                                                                      $i++
# Cloud
if ($selected[$i]) { Write-Section "Google Drive";       Install-Winget "Google.GoogleDrive" "Google Drive" };                                                                      $i++
# Dev
if ($selected[$i]) { Write-Section "VS Code";            Install-Winget "Microsoft.VisualStudioCode" "VS Code" };                                                                   $i++
if ($selected[$i]) { Write-Section "Node.js LTS";        Install-Winget "OpenJS.NodeJS.LTS" "Node.js LTS" };                                                                        $i++
if ($selected[$i]) { Write-Section "Deno";               Install-Winget "DenoLand.Deno" "Deno" };                                                                                   $i++
if ($selected[$i]) { Write-Section "uv";                 Install-Winget "astral-sh.uv" "uv" };                                                                                      $i++
if ($selected[$i]) { Write-Section "git";                Install-Winget "Git.Git" "Git" };                                                                                          $i++
if ($selected[$i]) { Write-Section "gh CLI";             Install-Winget "GitHub.cli" "gh CLI" };                                                                                    $i++
# Media
if ($selected[$i]) { Write-Section "OBS Studio";         Install-Winget "OBSProject.OBSStudio" "OBS Studio" };                                                                      $i++
if ($selected[$i]) { Write-Section "Audacity";           Install-Winget "Audacity.Audacity" "Audacity" };                                                                           $i++
if ($selected[$i]) { Write-Section "FFmpeg";             Install-Winget "Gyan.FFmpeg" "FFmpeg" };                                                                                   $i++
if ($selected[$i]) { Write-Section "yt-dlp";             Install-Winget "yt-dlp.yt-dlp" "yt-dlp" };                                                                                $i++
if ($selected[$i]) { Write-Section "Foxit PDF Reader";   Install-Winget "Foxit.FoxitReader" "Foxit PDF Reader" };                                                                   $i++
# Utilities
if ($selected[$i]) { Write-Section "Macrium Reflect";    Install-Winget "Macrium.Reflect.Free" "Macrium Reflect Free" };                                                            $i++
if ($selected[$i]) { Write-Section "Wise Uninstaller";   Install-Winget "WiseCleaner.WiseProgramUninstaller" "Wise Program Uninstaller" };                                          $i++
if ($selected[$i]) { Write-Section "Zoom";               Install-Winget "Zoom.Zoom" "Zoom" };                                                                                       $i++
if ($selected[$i]) { Write-Section "Messenger";          Install-Winget "Meta.Messenger" "Messenger" };                                                                             $i++
# Gaming
if ($selected[$i]) { Write-Section "GeForce NOW";        Install-Winget "Nvidia.GeForceNow" "NVIDIA GeForce NOW" };                                                                 $i++
if ($selected[$i]) { Write-Section "Steam";              Install-Winget "Valve.Steam" "Steam" };                                                                                    $i++
if ($selected[$i]) { Write-Section "Epic Games";         Install-Winget "EpicGames.EpicGamesLauncher" "Epic Games Launcher" };                                                      $i++
# Apps
if ($selected[$i]) { Write-Section "Canva";              Install-Winget "Canva.Canva" "Canva" };                                                                                    $i++

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
Write-Host "       Required for GadgetPack to read CPU temp/watts sensors" -ForegroundColor DarkGray
Write-Host "    4. Add Brave + GadgetPack to Startup folder" -ForegroundColor White
Write-Host "    5. Set execution policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
Write-Host ""
Write-Host "  Manual installs still needed:" -ForegroundColor Yellow
Write-Host "    NinjaTrader 8 / thinkorswim / Office 2010 / Epson Scan 2" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to close"