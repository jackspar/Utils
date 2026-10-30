# ============================================================
#  MyApps-Setup-Offline.ps1
#  Install JR's standard Windows desktop apps -- OFFLINE version
#  Uses local installers from .\installers\ (no internet needed)
#  Run: powershell -ExecutionPolicy Bypass -File MyApps-Setup-Offline.ps1
#  Stage installers first with: ..\Stage-MyApps-Offline.ps1
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "MyApps-Setup-Offline"

try {
    $raw = $Host.UI.RawUI
    $newBuf = New-Object System.Management.Automation.Host.Size(130, 3000)
    $newWin = New-Object System.Management.Automation.Host.Size(130, 45)
    if ($raw.BufferSize.Width -lt 130) { $raw.BufferSize = $newBuf }
    $raw.WindowSize = $newWin
} catch {}

$installersDir = Join-Path $PSScriptRoot "installers"

# ---- HELPERS ----

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host "   MYAPPS-SETUP  [OFFLINE]                           " -ForegroundColor Cyan
    Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm')   |   $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  ====================================================" -ForegroundColor Blue
}

function Write-Section($text) {
    Write-Host ""; Write-Host "  -- $text --" -ForegroundColor Yellow
}

function Install-Local($label) {
    $dir = Join-Path $installersDir $label
    if (-not (Test-Path $dir)) {
        Write-Host "  [FAIL] $label - folder not found: $dir" -ForegroundColor Red
        Write-Host "         Run Stage-MyApps-Offline.ps1 first." -ForegroundColor Yellow
        return
    }
    $installer = Get-ChildItem $dir -Include "*.exe","*.msi","*.msix" -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $installer) {
        Write-Host "  [FAIL] $label - no installer in $dir" -ForegroundColor Red
        return
    }
    Write-Host "  Installing $label from $($installer.Name)..." -ForegroundColor Gray
    $ext = $installer.Extension.ToLower()
    if ($ext -eq ".msi") {
        $proc = Start-Process msiexec -ArgumentList "/i `"$($installer.FullName)`" /quiet /norestart" -Wait -PassThru
    } elseif ($ext -eq ".msix" -or $ext -eq ".appx") {
        Add-AppxPackage -Path $installer.FullName -ErrorAction SilentlyContinue
        $proc = $null
    } else {
        # Try Inno/NSIS silent flags
        $proc = Start-Process $installer.FullName -ArgumentList "/VERYSILENT /NORESTART /S" -Wait -PassThru
    }
    if ($proc -and $proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        Write-Host "  [WARN] $label (exit $($proc.ExitCode)) - may need manual check" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] $label" -ForegroundColor Green
    }
}

function Install-GadgetPack {
    # 8GadgetPack v31 -- USE LOCAL MSI ONLY. Do NOT upgrade to newer versions.
    $localMsi = Join-Path $installersDir "8GadgetPack\8GadgetPackSetup.msi"
    if (Test-Path $localMsi) {
        Write-Host "  Installing 8GadgetPack v31 from offline copy..." -ForegroundColor Gray
        Start-Process msiexec -ArgumentList "/i `"$localMsi`" /quiet /norestart" -Wait
        Write-Host "  [OK] 8GadgetPack v31 installed" -ForegroundColor Green
        Write-Host "  NOTE: Restore gadgets from: C:\zPC-Beelink\8GadgetPack-backup\" -ForegroundColor DarkGray
    } else {
        Write-Host "  [FAIL] 8GadgetPack - MSI not found at: $localMsi" -ForegroundColor Red
        Write-Host "         Copy 8GadgetPackSetup.msi to: $(Split-Path $localMsi -Parent)" -ForegroundColor Yellow
    }
}

# ---- MENU ITEMS ----
$apps = @(
    @{ Label = "ExplorerPatcher"; Cat = "Shell/UI";  Note = "Classic Explorer/taskbar" }
    @{ Label = "Open Shell";      Cat = "Shell/UI";  Note = "Classic cascading Start Menu" }
    @{ Label = "PowerToys";       Cat = "Shell/UI";  Note = "Alt+Space, FancyZones" }
    @{ Label = "8GadgetPack";     Cat = "Shell/UI";  Note = "Desktop gadgets (LOCAL MSI v31, NEVER update)" }
    @{ Label = "Brave";           Cat = "Browser";   Note = "Primary browser" }
    @{ Label = "Firefox";         Cat = "Browser";   Note = "Secondary + PWAs" }
    @{ Label = "HWiNFO64";        Cat = "Hardware";  Note = "Sensors -- enable Shared Memory" }
    @{ Label = "Core Temp";       Cat = "Hardware";  Note = "CPU temp per-core" }
    @{ Label = "CPU-Z";           Cat = "Hardware";  Note = "CPU/RAM info" }
    @{ Label = "CrystalDiskMark"; Cat = "Hardware";  Note = "Disk speed benchmark" }
    @{ Label = "Everything";      Cat = "File/Disk"; Note = "Instant filename search" }
    @{ Label = "WizTree";         Cat = "File/Disk"; Note = "Disk space treemap" }
    @{ Label = "WinDirStat";      Cat = "File/Disk"; Note = "Disk usage treemap" }
    @{ Label = "7-Zip";           Cat = "File/Disk"; Note = "Archive manager" }
    @{ Label = "Google Drive";    Cat = "Cloud";     Note = "Google Drive desktop sync" }
    @{ Label = "VS Code";         Cat = "Dev";       Note = "Code editor" }
    @{ Label = "Node.js LTS";     Cat = "Dev";       Note = "JS runtime" }
    @{ Label = "Deno";            Cat = "Dev";       Note = "Modern JS/TS runtime" }
    @{ Label = "uv";              Cat = "Dev";       Note = "Python package manager" }
    @{ Label = "git";             Cat = "Dev";       Note = "Version control" }
    @{ Label = "gh CLI";          Cat = "Dev";       Note = "GitHub CLI" }
    @{ Label = "OBS Studio";      Cat = "Media";     Note = "Screen recording / streaming" }
    @{ Label = "Audacity";        Cat = "Media";     Note = "Audio editor" }
    @{ Label = "FFmpeg";          Cat = "Media";     Note = "Video/audio CLI" }
    @{ Label = "yt-dlp";          Cat = "Media";     Note = "Video downloader CLI" }
    @{ Label = "Foxit PDF";       Cat = "Media";     Note = "PDF reader" }
    @{ Label = "Macrium Reflect"; Cat = "Utility";   Note = "Disk imaging / backup" }
    @{ Label = "Wise Uninstaller";Cat = "Utility";   Note = "Preferred uninstaller" }
    @{ Label = "Zoom";            Cat = "Utility";   Note = "Video conferencing" }
    @{ Label = "Messenger";       Cat = "Utility";   Note = "Facebook Messenger" }
    @{ Label = "GeForce NOW";     Cat = "Gaming";    Note = "Cloud gaming" }
    @{ Label = "Steam";           Cat = "Gaming";    Note = "Steam gaming client" }
    @{ Label = "Epic Games";      Cat = "Gaming";    Note = "Epic Games store" }
    @{ Label = "Canva";           Cat = "App";       Note = "Design tool" }
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

# ---- CHECK OFFLINE FOLDER ----
Write-Host ""
Write-Host "  Checking offline installer cache..." -ForegroundColor DarkGray
for ($x = 0; $x -lt $apps.Count; $x++) {
    $dir   = Join-Path $installersDir $apps[$x].Label
    $found = (Test-Path $dir) -and ((Get-ChildItem $dir -File -Recurse -ErrorAction SilentlyContinue).Count -gt 0)
    $apps[$x].IsInst = $false
    $apps[$x].HasUpd = $false
    $apps[$x].HasLocal = $found
}

# ---- INIT STATES ----
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
    Write-Host "  [ ]=skip  [X]=install  [!]=NEVER  *=offline installer ready" -ForegroundColor DarkGray
    Write-Host ""

    $catStart = 0
    while ($catStart -lt $apps.Count) {
        $cat    = $apps[$catStart].Cat
        $catEnd = $catStart
        while ($catEnd -lt $apps.Count -and $apps[$catEnd].Cat -eq $cat) { $catEnd++ }
        Write-Host ("  [ {0} ]" -f $cat) -ForegroundColor DarkCyan

        $ci = $catStart
        while ($ci -lt $catEnd) {
            $row = @()
            for ($c = 0; $c -lt 4 -and ($ci + $c) -lt $catEnd; $c++) { $row += ($ci + $c) }
            for ($c = 0; $c -lt $row.Count; $c++) {
                $idx    = $row[$c]
                $st     = $states[$idx]
                $isCur  = ($idx -eq $cursor)
                $prefix = if ($isCur) { ">>" } else { "  " }
                $chk    = if ($st -eq 1) { "[X]" } elseif ($st -eq 2) { "[!]" } else { "[ ]" }
                $color  = if ($isCur) { "Cyan" } elseif ($st -eq 1) { "Green" } elseif ($st -eq 2) { "DarkRed" } else { "DarkGray" }
                $marker = if ($apps[$idx].HasLocal) { "*" } else { " " }
                $name   = $apps[$idx].Label
                if ($name.Length -gt 17) { $name = $name.Substring(0, 17) }
                $slot   = ("{0}{1} {2,2}. {3} {4}" -f $prefix, $chk, ($idx+1), $name.PadRight(17), $marker).PadRight(32)
                if ($c -eq ($row.Count - 1)) { Write-Host $slot -ForegroundColor $color }
                else { Write-Host $slot -ForegroundColor $color -NoNewline }
            }
            $ci += 4
        }
        $catStart = $catEnd
    }

    Write-Host ""
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
        for ($k = 0; $k -lt $total; $k++) { if ($states[$k] -ne 2) { $states[$k] = 1 } }
    } elseif ($ch -eq "N") {
        for ($k = 0; $k -lt $total; $k++) { if ($states[$k] -ne 2) { $states[$k] = 0 } }
    }
}

# ---- INSTALL ----
Write-Banner
Write-Host ""
Write-Host "  Starting offline installs from: $installersDir" -ForegroundColor Yellow

$i = 0
# Shell/UI
if ($states[$i] -eq 1) { Write-Section "ExplorerPatcher"; Install-Local "ExplorerPatcher" }; $i++
if ($states[$i] -eq 1) { Write-Section "Open Shell";      Install-Local "Open Shell" };       $i++
if ($states[$i] -eq 1) { Write-Section "PowerToys";       Install-Local "PowerToys" };        $i++
if ($states[$i] -eq 1) { Write-Section "8GadgetPack";     Install-GadgetPack };               $i++
# Browsers
if ($states[$i] -eq 1) { Write-Section "Brave";    Install-Local "Brave" };   $i++
if ($states[$i] -eq 1) { Write-Section "Firefox";  Install-Local "Firefox" }; $i++
# Hardware
if ($states[$i] -eq 1) { Write-Section "HWiNFO64";       Install-Local "HWiNFO64" };       $i++
if ($states[$i] -eq 1) { Write-Section "Core Temp";       Install-Local "Core Temp" };      $i++
if ($states[$i] -eq 1) { Write-Section "CPU-Z";           Install-Local "CPU-Z" };          $i++
if ($states[$i] -eq 1) { Write-Section "CrystalDiskMark"; Install-Local "CrystalDiskMark" };$i++
# File/Disk
if ($states[$i] -eq 1) { Write-Section "Everything"; Install-Local "Everything" }; $i++
if ($states[$i] -eq 1) { Write-Section "WizTree";    Install-Local "WizTree" };    $i++
if ($states[$i] -eq 1) { Write-Section "WinDirStat"; Install-Local "WinDirStat" }; $i++
if ($states[$i] -eq 1) { Write-Section "7-Zip";      Install-Local "7-Zip" };      $i++
# Cloud
if ($states[$i] -eq 1) { Write-Section "Google Drive"; Install-Local "Google Drive" }; $i++
# Dev
if ($states[$i] -eq 1) { Write-Section "VS Code";     Install-Local "VS Code" };    $i++
if ($states[$i] -eq 1) { Write-Section "Node.js LTS"; Install-Local "Node.js LTS" };$i++
if ($states[$i] -eq 1) { Write-Section "Deno";        Install-Local "Deno" };       $i++
if ($states[$i] -eq 1) { Write-Section "uv";          Install-Local "uv" };         $i++
if ($states[$i] -eq 1) { Write-Section "git";         Install-Local "git" };        $i++
if ($states[$i] -eq 1) { Write-Section "gh CLI";      Install-Local "gh CLI" };     $i++
# Media
if ($states[$i] -eq 1) { Write-Section "OBS Studio"; Install-Local "OBS Studio" }; $i++
if ($states[$i] -eq 1) { Write-Section "Audacity";   Install-Local "Audacity" };   $i++
if ($states[$i] -eq 1) { Write-Section "FFmpeg";     Install-Local "FFmpeg" };     $i++
if ($states[$i] -eq 1) { Write-Section "yt-dlp";     Install-Local "yt-dlp" };     $i++
if ($states[$i] -eq 1) { Write-Section "Foxit PDF";  Install-Local "Foxit PDF" };  $i++
# Utilities
if ($states[$i] -eq 1) { Write-Section "Macrium Reflect";  Install-Local "Macrium Reflect" };  $i++
if ($states[$i] -eq 1) { Write-Section "Wise Uninstaller"; Install-Local "Wise Uninstaller" }; $i++
if ($states[$i] -eq 1) { Write-Section "Zoom";             Install-Local "Zoom" };             $i++
if ($states[$i] -eq 1) { Write-Section "Messenger";        Install-Local "Messenger" };        $i++
# Gaming
if ($states[$i] -eq 1) { Write-Section "GeForce NOW"; Install-Local "GeForce NOW" }; $i++
if ($states[$i] -eq 1) { Write-Section "Steam";       Install-Local "Steam" };       $i++
if ($states[$i] -eq 1) { Write-Section "Epic Games";  Install-Local "Epic Games" };  $i++
# Apps
if ($states[$i] -eq 1) { Write-Section "Canva"; Install-Local "Canva" }; $i++

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
Write-Host "    4. Add Brave + 8GadgetPack to Startup folder" -ForegroundColor White
Write-Host "    5. Set execution policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
Write-Host ""
Write-Host "  Manual installs still needed:" -ForegroundColor Yellow
Write-Host "    NinjaTrader 8 / thinkorswim / Office 2010 / Epson Scan 2" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to close"
