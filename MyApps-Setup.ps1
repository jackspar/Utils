# ============================================================
#  MyApps-Setup.ps1
#  Install JR's standard Windows desktop apps on any PC
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
    Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm')   |   Setting up: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  ====================================================" -ForegroundColor Blue
}

function Write-Section($text) {
    Write-Host ""
    Write-Host "  -- $text --" -ForegroundColor Yellow
}

function Install-Winget($id, $label) {
    Write-Host "  Installing $label..." -ForegroundColor Gray
    $result = winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-Host "  [OK] $label" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $label - check manually (exit $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

function Install-GitHubLatest($repo, $assetFilter, $label) {
    Write-Host "  Downloading $label from GitHub..." -ForegroundColor Gray
    try {
        $rel  = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -ErrorAction Stop
        $asset = $rel.assets | Where-Object { $_.name -like $assetFilter } | Select-Object -First 1
        if (-not $asset) { Write-Host "  [WARN] $label - asset not found in release" -ForegroundColor Yellow; return }
        $tmp = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -ErrorAction Stop
        Start-Process $tmp -Wait
        Write-Host "  [OK] $label installed" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] $label - download failed: $_" -ForegroundColor Yellow
    }
}

# ---- MENU ITEMS ----
# Each: @{ Label; Tag; Category; Note }
$apps = @(
    # Shell / UI
    @{ Label = "ExplorerPatcher         "; Tag = "EP";     Cat = "Shell/UI";  Note = "Classic Explorer/taskbar" }
    @{ Label = "Open Shell              "; Tag = "OS";     Cat = "Shell/UI";  Note = "Classic cascading Start Menu" }
    @{ Label = "Microsoft PowerToys     "; Tag = "PT";     Cat = "Shell/UI";  Note = "Alt+Space launcher, FancyZones, etc." }
    # Browsers
    @{ Label = "Brave Browser           "; Tag = "BR";     Cat = "Browser";   Note = "Primary browser (winget)" }
    @{ Label = "Firefox                 "; Tag = "FF";     Cat = "Browser";   Note = "Secondary browser + PWAs (winget)" }
    # Dev
    @{ Label = "Visual Studio Code      "; Tag = "VSC";    Cat = "Dev";       Note = "winget" }
    @{ Label = "gh CLI                  "; Tag = "GH";     Cat = "Dev";       Note = "GitHub CLI (winget)" }
    # Utilities
    @{ Label = "Macrium Reflect Free    "; Tag = "MAC";    Cat = "Utility";   Note = "Backup/imaging (winget)" }
    @{ Label = "Wise Program Uninstaller"; Tag = "WPU";    Cat = "Utility";   Note = "winget" }
    @{ Label = "GeForce NOW             "; Tag = "GFN";    Cat = "Utility";   Note = "Cloud gaming (winget)" }
    @{ Label = "Steam                   "; Tag = "STM";    Cat = "App";       Note = "Gaming (winget)" }
    @{ Label = "Canva                   "; Tag = "CVA";    Cat = "App";       Note = "Design (winget)" }
)

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
            Write-Host ("  {0,-6}  {1}" -f "", "[ $($apps[$i].Cat) ]") -ForegroundColor DarkCyan
            $lastCat = $apps[$i].Cat
        }
        $num = $i + 1
        $chk = if ($selected[$i]) { "[X]" } else { "[ ]" }
        $col = if ($selected[$i]) { "Green" } else { "DarkGray" }
        Write-Host ("  {0} {1,2}. {2}  {3}" -f $chk, $num, $apps[$i].Label, $apps[$i].Note) -ForegroundColor $col
    }

    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  MANUAL STEPS (cannot be automated):" -ForegroundColor DarkGray
    Write-Host "    - Sidebar427       sidebar427.net" -ForegroundColor DarkGray
    Write-Host "    - NinjaTrader 8    ninjatrader.com  (requires account)" -ForegroundColor DarkGray
    Write-Host "    - thinkorswim      schwab.com/trading/thinkorswim" -ForegroundColor DarkGray
    Write-Host "    - Office 2010      from install media / backup" -ForegroundColor DarkGray
    Write-Host "    - Epson Scan 2     epson.com (printer-specific)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press: number (1-$($apps.Count)) · A (all) · N (none) · ENTER (install) · Q (quit)" -ForegroundColor Yellow
    Write-Host ""
}

$selected = @(,$true * $apps.Count)

while ($true) {
    Show-Menu $selected
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $ch  = $key.Character.ToString().ToUpper()

    if ($ch -eq "Q") {
        Write-Host "  Cancelled." -ForegroundColor DarkGray
        Read-Host "  Press Enter to close"
        exit
    }
    elseif ($key.VirtualKeyCode -eq 13) { break }
    elseif ($ch -eq "A") { $selected = @(,$true * $apps.Count) }
    elseif ($ch -eq "N") { $selected = @(,$false * $apps.Count) }
    else {
        for ($n = $apps.Count; $n -ge 1; $n--) {
            if ($ch -eq "$n"[0] -and $key.VirtualKeyCode -ge 49 -and $key.VirtualKeyCode -le 57) {
                $selected[$n-1] = -not $selected[$n-1]; break
            }
        }
        # Handle multi-digit: just single digit 1-9 for now (12 items max)
        $idx = [int][string]$ch - 1
        if ($idx -ge 0 -and $idx -lt $apps.Count) { $selected[$idx] = -not $selected[$idx] }
    }
}

# ---- INSTALL ----

Write-Banner
Write-Host ""
Write-Host "  Starting installs..." -ForegroundColor Yellow
Write-Host ""

# Verify winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  [WARN] winget not found. Install App Installer from the Microsoft Store first." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 1
}

$idx = 0

# ExplorerPatcher
if ($selected[$idx]) {
    Write-Section "ExplorerPatcher"
    Install-GitHubLatest "valinet/ExplorerPatcher" "ep_setup.exe" "ExplorerPatcher"
}; $idx++

# Open Shell
if ($selected[$idx]) {
    Write-Section "Open Shell"
    Install-GitHubLatest "Open-Shell/Open-Shell-Menu" "OpenShellSetup_*.exe" "Open Shell"
}; $idx++

# PowerToys
if ($selected[$idx]) {
    Write-Section "PowerToys"
    Install-Winget "Microsoft.PowerToys" "Microsoft PowerToys"
}; $idx++

# Brave
if ($selected[$idx]) {
    Write-Section "Brave Browser"
    Install-Winget "Brave.Brave" "Brave Browser"
}; $idx++

# Firefox
if ($selected[$idx]) {
    Write-Section "Firefox"
    Install-Winget "Mozilla.Firefox" "Mozilla Firefox"
}; $idx++

# VS Code
if ($selected[$idx]) {
    Write-Section "Visual Studio Code"
    Install-Winget "Microsoft.VisualStudioCode" "VS Code"
}; $idx++

# gh CLI
if ($selected[$idx]) {
    Write-Section "gh CLI"
    Install-Winget "GitHub.cli" "GitHub CLI"
}; $idx++

# Macrium Reflect
if ($selected[$idx]) {
    Write-Section "Macrium Reflect Free"
    Install-Winget "Macrium.Reflect.Free" "Macrium Reflect Free"
}; $idx++

# Wise Program Uninstaller
if ($selected[$idx]) {
    Write-Section "Wise Program Uninstaller"
    Install-Winget "WiseCleaner.WiseProgramUninstaller" "Wise Program Uninstaller"
}; $idx++

# GeForce NOW
if ($selected[$idx]) {
    Write-Section "GeForce NOW"
    Install-Winget "Nvidia.GeForceNow" "NVIDIA GeForce NOW"
}; $idx++

# Steam
if ($selected[$idx]) {
    Write-Section "Steam"
    Install-Winget "Valve.Steam" "Steam"
}; $idx++

# Canva
if ($selected[$idx]) {
    Write-Section "Canva"
    Install-Winget "Canva.Canva" "Canva"
}; $idx++

# ---- DONE ----

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host "   INSTALL COMPLETE                                   " -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Blue
Write-Host ""
Write-Host "  Next manual steps:" -ForegroundColor Yellow
Write-Host "    1. Sidebar427     sidebar427.net" -ForegroundColor White
Write-Host "    2. NinjaTrader 8  ninjatrader.com" -ForegroundColor White
Write-Host "    3. thinkorswim    schwab.com/trading/thinkorswim" -ForegroundColor White
Write-Host "    4. Office 2010    from install media" -ForegroundColor White
Write-Host "    5. Epson Scan 2   from epson.com" -ForegroundColor White
Write-Host ""
Write-Host "  After ExplorerPatcher + Open Shell:" -ForegroundColor Yellow
Write-Host "    - Restart Explorer (ExplorerPatcher Properties > Restart File Explorer)" -ForegroundColor White
Write-Host "    - Configure Open Shell > Start Menu style > Classic" -ForegroundColor White
Write-Host "    - Create My Utilities folder in Start Menu" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to close"