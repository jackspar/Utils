# ============================================================
#  Cleanup-Windows.ps1
#  Generic Windows routine cleanup — works on any Windows PC
#  Run from: powershell -ExecutionPolicy Bypass -File "Cleanup-Windows.ps1"
#  Or via: irm https://raw.githubusercontent.com/jackspar/utils/main/Cleanup-Windows.ps1 | iex
# ============================================================

# Auto-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Cleanup-Windows"

# ---- HELPERS ----

function Get-FolderSize($path) {
    if (-not (Test-Path $path)) { return 0 }
    (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
}

function Format-MB($bytes) {
    if ($bytes -ge 1GB) { return "$([math]::Round($bytes/1GB,1)) GB" }
    return "$([math]::Round($bytes/1MB,0)) MB"
}

function Write-Title($text) {
    $w = 62
    $pad = [math]::Max(0, ($w - $text.Length - 2) / 2)
    $line = "=" * $w
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host (" " * [math]::Floor($pad) + $text) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

function Clear-Folder($path, $label) {
    if (-not (Test-Path $path)) {
        Write-Host "  [SKIP] $label not found" -ForegroundColor DarkGray
        return 0
    }
    $before = Get-FolderSize $path
    Get-ChildItem $path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $after = Get-FolderSize $path
    $freed = [math]::Max(0, $before - $after)
    Write-Host "  [OK] $label — freed $(Format-MB $freed)" -ForegroundColor Green
    return $freed
}

# ---- SCAN: estimate sizes before the menu ----

Clear-Host
Write-Host ""
Write-Host "  Scanning for cleanable space..." -ForegroundColor Yellow

$estWinTemp   = Get-FolderSize "C:\Windows\Temp"
$estUserTemp  = Get-FolderSize "$env:LOCALAPPDATA\Temp"
$estWUpdate   = Get-FolderSize "C:\Windows\SoftwareDistribution\Download"
$estPrefetch  = Get-FolderSize "C:\Windows\Prefetch"
$estEventLogs = (Get-ChildItem "C:\Windows\System32\winevt\Logs" -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum

$driveFree = (Get-PSDrive C).Free

# ---- MENU ----

function Show-Menu($selected) {
    Clear-Host
    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host "   CLEANUP-WINDOWS                                    " -ForegroundColor Cyan
    Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm')   |   C: free: $(Format-MB $driveFree)" -ForegroundColor White
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  Select items to clean  (number to toggle, ENTER to run, Q to quit)" -ForegroundColor Yellow
    Write-Host "  A = Select All   N = Select None" -ForegroundColor DarkGray
    Write-Host ""

    $items = @(
        @{ Label = "Windows Temp         "; Est = $estWinTemp  }
        @{ Label = "User Temp ($env:USERNAME)"; Est = $estUserTemp }
        @{ Label = "Windows Update Cache "; Est = $estWUpdate  }
        @{ Label = "Prefetch Cache       "; Est = $estPrefetch }
        @{ Label = "Event Viewer Logs    "; Est = $estEventLogs }
        @{ Label = "Disk Cleanup (22 cat)"; Est = $null }
        @{ Label = "DISM Component Store "; Est = $null }
    )

    for ($i = 0; $i -lt $items.Count; $i++) {
        $num  = $i + 1
        $chk  = if ($selected[$i]) { "[X]" } else { "[ ]" }
        $est  = if ($items[$i].Est -ne $null) { "~$(Format-MB $items[$i].Est)" } else { "~varies (slow)" }
        $col  = if ($selected[$i]) { "Green" } else { "DarkGray" }
        Write-Host ("  {0} {1}. {2}  {3}" -f $chk, $num, $items[$i].Label, $est) -ForegroundColor $col
    }

    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Blue
    Write-Host "  Press: number (1-7) · A (all) · N (none) · ENTER (run) · Q (quit)" -ForegroundColor Yellow
    Write-Host ""
}

$selected = @($true, $true, $true, $true, $true, $true, $true)

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
    elseif ($ch -eq "A") { $selected = @($true, $true, $true, $true, $true, $true, $true) }
    elseif ($ch -eq "N") { $selected = @($false, $false, $false, $false, $false, $false, $false) }
    elseif ($ch -ge "1" -and $ch -le "7") { $idx = [int]$ch - 1; $selected[$idx] = -not $selected[$idx] }
}

# ---- RUN SELECTED ----

Clear-Host
Write-Title "RUNNING CLEANUP"
$startFree = (Get-PSDrive C).Free

if ($selected[0]) {
    Write-Host ""; Write-Host "  [1/7] Stopping Windows Update services..." -ForegroundColor Gray
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name bits    -Force -ErrorAction SilentlyContinue
    Clear-Folder "C:\Windows\Temp" "Windows Temp" | Out-Null
}
if ($selected[1]) { Clear-Folder "$env:LOCALAPPDATA\Temp" "User Temp" | Out-Null }
if ($selected[2]) { Clear-Folder "C:\Windows\SoftwareDistribution\Download" "Update Cache" | Out-Null }
if ($selected[3]) { Clear-Folder "C:\Windows\Prefetch" "Prefetch Cache" | Out-Null }
if ($selected[0] -or $selected[2]) {
    Write-Host "  Restarting Windows Update services..." -ForegroundColor Gray
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Start-Service -Name bits    -ErrorAction SilentlyContinue
}

if ($selected[4]) {
    Write-Host ""; Write-Host "  [5/7] Clearing Event Viewer logs..." -ForegroundColor Gray
    $logsBefore = (Get-ChildItem "C:\Windows\System32\winevt\Logs" -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $count = 0
    wevtutil el 2>$null | ForEach-Object { wevtutil cl "$_" 2>$null; $count++ }
    $logsAfter = (Get-ChildItem "C:\Windows\System32\winevt\Logs" -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host "  [OK] Event logs ($count) — freed $(Format-MB ([math]::Max(0,$logsBefore - $logsAfter)))" -ForegroundColor Green
}

if ($selected[5]) {
    Write-Host ""; Write-Host "  [6/7] Configuring and running Disk Cleanup (1-3 min)..." -ForegroundColor Gray
    $regBase = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    @("Active Setup Temp Folders","BranchCache","Device Driver Packages","Downloaded Program Files",
      "Memory Dump Files","Old ChkDsk Files","Previous Installations","Recycle Bin","Setup Log Files",
      "System error memory dump files","System error minidump files","Temporary Files","Temporary Setup Files",
      "Thumbnail Cache","Update Cleanup","Upgrade Discarded Files","Windows Defender",
      "Windows Error Reporting Archive Files","Windows Error Reporting Queue Files",
      "Windows Error Reporting System Archive Files","Windows Error Reporting System Queue Files",
      "Windows Upgrade Log Files") | ForEach-Object {
        $key = "$regBase\$_"
        if (Test-Path $key) { Set-ItemProperty -Path $key -Name StateFlags0099 -Value 2 -Type DWord -ErrorAction SilentlyContinue }
    }
    $beforeClean = (Get-PSDrive C).Free
    Start-Process cleanmgr -ArgumentList "/sagerun:99" -Wait -WindowStyle Hidden
    Write-Host "  [OK] Disk Cleanup complete — freed $(Format-MB ([math]::Max(0,(Get-PSDrive C).Free - $beforeClean)))" -ForegroundColor Green
}

if ($selected[6]) {
    Write-Host ""; Write-Host "  [7/7] DISM Component Cleanup (5-15 min — please wait)..." -ForegroundColor Yellow
    $beforeDism = (Get-PSDrive C).Free
    dism /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
    $freed = [math]::Max(0,(Get-PSDrive C).Free - $beforeDism)
    if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] DISM complete — freed $(Format-MB $freed)" -ForegroundColor Green }
    else { Write-Host "  [WARN] DISM reported an issue (may still have cleaned up)" -ForegroundColor Yellow }
}

# ---- SUMMARY ----

$endFree = (Get-PSDrive C).Free
Write-Title "CLEANUP COMPLETE"
Write-Host ""
Write-Host "  Date:          $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor White
Write-Host "  C: free before: $(Format-MB $startFree)" -ForegroundColor Gray
Write-Host "  C: free after:  $(Format-MB $endFree)" -ForegroundColor Green
Write-Host "  Total freed:    $(Format-MB ([math]::Max(0,$endFree - $startFree)))" -ForegroundColor Cyan
Write-Host ""
Write-Host "  NOTE: Reboot recommended to fully release freed space" -ForegroundColor Yellow
Write-Host ""

$logDir = if ($PSScriptRoot) { $PSScriptRoot } else { "$env:TEMP" }
$logLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm') | Before: $(Format-MB $startFree) free | After: $(Format-MB $endFree) free | Freed: $(Format-MB ([math]::Max(0,$endFree - $startFree)))"
try { Add-Content -Path (Join-Path $logDir "cleanup_log.txt") -Value $logLine -ErrorAction SilentlyContinue } catch {}
Write-Host "  Log: $(Join-Path $logDir 'cleanup_log.txt')" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Press Enter to close"
