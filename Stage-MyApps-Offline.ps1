# ============================================================
#  Stage-MyApps-Offline.ps1
#  Stages all MyApps installers into MyApps-Offline\installers\
#  Sources: existing D: drive installers first, then downloads.
#  Run this on a machine WITH internet. Then copy MyApps-Offline\
#  to USB for offline use on a new PC.
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$offlineDir = Join-Path $scriptDir "MyApps-Offline\installers"

if (-not (Test-Path $offlineDir)) { New-Item -ItemType Directory -Path $offlineDir -Force | Out-Null }

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host "   STAGE MYAPPS OFFLINE                              " -ForegroundColor Cyan
Write-Host "   Destination: $offlineDir" -ForegroundColor White
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host ""

$ok = 0; $warn = 0; $skipped = 0

# Known local installer sources on D: drive (checked before downloading)
# Add paths in preference order (first found wins)
$localSources = @{
    "Open Shell"      = @("D:\BeeSER Downloads\OpenShellSetup_4_4_196.exe")
    "PowerToys"       = @("D:\OneDrive\w10 to w11 migration\PowerToys\PowerToysUserSetup-0.90.1-x64.exe")
    "8GadgetPack"     = @("D:\OneDrive\w10 to w11 migration\8GadgetPack\8GadgetPackSetup.msi",
                          "D:\BeeSER Downloads\8GadgetPackSetup.msi")
    "Google Drive"    = @("D:\OneDrive\Downloads\GoogleDriveSetup.exe",
                          "D:\BeeSER Downloads\GoogleDriveSetup.exe")
    "VS Code"         = @("D:\BeeSER Downloads\VSCodeUserSetup-x64-1.84.2.exe")
    "OBS Studio"      = @("D:\MyApps\OBS-Studio-31.0.1-Windows-Installer.exe")
    "Audacity"        = @("D:\BeeSER Downloads\audacity-win-3.7.4-64bit.exe",
                          "D:\BeeSER Downloads\audacity-win-3.7.3-64bit.exe",
                          "D:\BeeSER Downloads\audacity-win-3.7.0-64bit.exe")
    "Zoom"            = @("D:\BeeSER Downloads\ZoomInstallerFull.exe",
                          "D:\BeeSER Downloads\ZoomInstaller.exe")
    "Messenger"       = @("D:\BeeSER Downloads\Messenger.203.0.0.8.396.exe",
                          "D:\BeeSER Downloads\Messenger.196.0.0.4.210.exe")
    "GeForce NOW"     = @("D:\BeeSER Downloads\GeForceNOW-release.exe",
                          "D:\MyUtils\GeForceNOW-release.exe")
    "Steam"           = @("D:\BeeSER Downloads\SteamSetup.exe")
    "Epic Games"      = @("D:\MyUtils\EpicInstaller-15.7.0-290f3917d43e4c3294249035c7bab9a5.msi")
    "Canva"           = @("D:\BeeSER Downloads\Canva Setup 1.113.0.exe")
}

function Stage-App($label, $wingetId, $githubRepo, $githubFilter) {
    $dir = Join-Path $offlineDir $label
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # Already staged this session?
    $already = Get-ChildItem $dir -File -Recurse -ErrorAction SilentlyContinue
    if ($already.Count -gt 0) {
        Write-Host "  [SKIP] $label (already in offline folder)" -ForegroundColor DarkGray
        $script:skipped++; return
    }

    # Try local D: drive sources first
    $srcs = $localSources[$label]
    if ($srcs) {
        foreach ($src in $srcs) {
            if (Test-Path $src) {
                $fname = Split-Path $src -Leaf
                Copy-Item $src (Join-Path $dir $fname) -Force
                Write-Host "  [LOCAL] $label  <-- $(Split-Path $src -Parent)" -ForegroundColor DarkGreen
                $script:ok++; return
            }
        }
    }

    # Fall back to download
    if ($githubRepo) {
        Write-Host "  Downloading $label (GitHub)..." -ForegroundColor Gray
        try {
            $rel   = Invoke-RestMethod "https://api.github.com/repos/$githubRepo/releases/latest" -ErrorAction Stop
            $asset = $rel.assets | Where-Object { $_.name -like $githubFilter } | Select-Object -First 1
            if (-not $asset) { Write-Host "  [WARN] $label - asset not found on GitHub" -ForegroundColor Yellow; $script:warn++; return }
            $out   = Join-Path $dir $asset.name
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $out -ErrorAction Stop
            Write-Host "  [DL] $label -> $($asset.name)" -ForegroundColor Green
            $script:ok++
        } catch { Write-Host "  [WARN] $label - $_" -ForegroundColor Yellow; $script:warn++ }
    } elseif ($wingetId) {
        Write-Host "  Downloading $label (winget)..." -ForegroundColor Gray
        winget download --id $wingetId --download-directory $dir --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        $files = Get-ChildItem $dir -File -Recurse -ErrorAction SilentlyContinue
        if ($files.Count -gt 0) {
            Write-Host "  [DL] $label" -ForegroundColor Green; $script:ok++
        } else {
            Write-Host "  [WARN] $label - winget download failed (package may not support offline)" -ForegroundColor Yellow; $script:warn++
        }
    }
}

function Stage-GadgetPack {
    Stage-App "8GadgetPack" "" "" ""
}

# ---- Shell / UI ----
Stage-App "ExplorerPatcher" "" "valinet/ExplorerPatcher"    "ep_setup.exe"
Stage-App "Open Shell"      "" "Open-Shell/Open-Shell-Menu" "OpenShellSetup_*.exe"
Stage-App "PowerToys"       "Microsoft.PowerToys"      "" ""
Stage-GadgetPack

# ---- Browsers ----
Stage-App "Brave"    "Brave.Brave"     "" ""
Stage-App "Firefox"  "Mozilla.Firefox" "" ""

# ---- Hardware ----
Stage-App "HWiNFO64"        "REALiX.HWiNFO"                    "" ""
Stage-App "Core Temp"        "ALTEMPLtd.CoreTemp"                "" ""
Stage-App "CPU-Z"            "CPUID.CPU-Z"                       "" ""
Stage-App "CrystalDiskMark"  "CrystalDewWorld.CrystalDiskMark"   "" ""

# ---- File / Disk ----
Stage-App "Everything"  "voidtools.Everything"       "" ""
Stage-App "WizTree"     "AntibodySoftware.WizTree"   "" ""
Stage-App "WinDirStat"  "WinDirStat.WinDirStat"      "" ""
Stage-App "7-Zip"       "7zip.7zip"                  "" ""

# ---- Cloud ----
Stage-App "Google Drive" "Google.GoogleDrive" "" ""

# ---- Dev ----
Stage-App "VS Code"      "Microsoft.VisualStudioCode" "" ""
Stage-App "Node.js LTS"  "OpenJS.NodeJS.LTS"          "" ""
Stage-App "Deno"         "DenoLand.Deno"              "" ""
Stage-App "uv"           "astral-sh.uv"               "" ""
Stage-App "git"          "Git.Git"                    "" ""
Stage-App "gh CLI"       "GitHub.cli"                 "" ""

# ---- Media ----
Stage-App "OBS Studio"  "OBSProject.OBSStudio"   "" ""
Stage-App "Audacity"    "Audacity.Audacity"       "" ""
Stage-App "FFmpeg"      "Gyan.FFmpeg"             "" ""
Stage-App "yt-dlp"      "yt-dlp.yt-dlp"           "" ""
Stage-App "Foxit PDF"   "Foxit.FoxitReader"       "" ""

# ---- Utilities ----
Stage-App "Macrium Reflect"  "Macrium.Reflect.Free"                 "" ""
Stage-App "Wise Uninstaller" "WiseCleaner.WiseProgramUninstaller"   "" ""
Stage-App "Zoom"             "Zoom.Zoom"                            "" ""
Stage-App "Messenger"        "Meta.Messenger"                       "" ""

# ---- Gaming ----
Stage-App "GeForce NOW"  "Nvidia.GeForceNow"             "" ""
Stage-App "Steam"        "Valve.Steam"                   "" ""
Stage-App "Epic Games"   "EpicGames.EpicGamesLauncher"   "" ""

# ---- Apps ----
Stage-App "Canva" "Canva.Canva" "" ""

# ---- Summary ----
Write-Host ""
$size   = (Get-ChildItem $offlineDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$sizeMB = [Math]::Round($size / 1MB, 0)
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host ("   DONE: {0} OK  {1} WARN  {2} SKIPPED  ({3} MB total)" -f $ok, $warn, $skipped, $sizeMB) -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host ""
if ($warn -gt 0) {
    Write-Host "  Note: WARN items above need manual download -- see winget notes." -ForegroundColor Yellow
    Write-Host "  Place installers in: $offlineDir\<AppName>\" -ForegroundColor Yellow
    Write-Host ""
}
Write-Host "  Note: Some LOCAL copies may be older versions." -ForegroundColor DarkGray
Write-Host "  To refresh a specific app, delete its subfolder and re-run." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  NEXT STEP: Copy entire MyApps-Offline\ folder to USB." -ForegroundColor Green
Write-Host "  On target PC run: MyApps-Offline\MyApps-Setup-Offline.ps1" -ForegroundColor Green
Write-Host ""
Read-Host "  Press Enter to close"
