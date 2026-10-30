#Requires -Version 5.1
<#
.SYNOPSIS
    Assembles MyWin-Setup.exe -- a 7-Zip SFX that launches Start-MyWinSetup.ps1.

.DESCRIPTION
    Output: D:\Projects\Utils\MyWin-Setup.exe
    Contents: CoreApps-Bundle\ + Apply-WinConfig.ps1 + Install-CoreApps.ps1 + Start-MyWinSetup.ps1

    The SFX extracts to a temp folder, runs Start-MyWinSetup.ps1 via powershell.exe,
    then the GUI installer handles UAC elevation itself.

.NOTES
    Run on BeeSER after Backup-CoreApps.ps1 has staged the bundle.
    Requires 7-Zip installed (7z.exe + 7z.sfx at default path).
    NEVER run on BeeSER's apps -- this script only builds the EXE, nothing more.
#>

$ErrorActionPreference = 'Stop'

$ScriptDir   = $PSScriptRoot
$OutputExe   = Join-Path $ScriptDir "MyWin-Setup.exe"
$SfxModule   = "C:\Program Files\7-Zip\7z.sfx"
$SevenZipExe = "C:\Program Files\7-Zip\7z.exe"
$BundleDir   = Join-Path $ScriptDir "CoreApps-Bundle"
$TempStage   = Join-Path $env:TEMP "MyWinSetup-Stage-$(Get-Random)"
$ArchivePath = Join-Path $env:TEMP "MyWinSetup-$(Get-Random).7z"

Write-Host ""
Write-Host "  Build-MyWinSetup  --  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host ""

# -- Prerequisites check -------------------------------------------------------
function Check($label, [scriptblock]$test) {
    Write-Host "  Check: $label ... " -NoNewline
    try {
        & $test
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "MISSING" -ForegroundColor Red
        throw "Prerequisite failed: $label -- $_"
    }
}

Check "7z.exe" { if (!(Test-Path $SevenZipExe)) { throw "Not found: $SevenZipExe" } }
Check "7z.sfx" { if (!(Test-Path $SfxModule))   { throw "Not found: $SfxModule" } }
Check "CoreApps-Bundle\" {
    if (!(Test-Path $BundleDir)) { throw "Not found: $BundleDir`nRun Backup-CoreApps.ps1 first." }
}
Check "Apply-WinConfig.ps1" {
    if (!(Test-Path (Join-Path $ScriptDir "Apply-WinConfig.ps1"))) { throw "Not found in $ScriptDir" }
}
Check "Install-CoreApps.ps1" {
    if (!(Test-Path (Join-Path $ScriptDir "Install-CoreApps.ps1"))) { throw "Not found in $ScriptDir" }
}
Check "Start-MyWinSetup.ps1" {
    if (!(Test-Path (Join-Path $ScriptDir "Start-MyWinSetup.ps1"))) { throw "Not found in $ScriptDir" }
}

Write-Host ""

# -- Stage files ---------------------------------------------------------------
Write-Host "  Staging files to temp ... " -NoNewline
New-Item -ItemType Directory -Force -Path $TempStage | Out-Null

Copy-Item (Join-Path $ScriptDir "Apply-WinConfig.ps1")   $TempStage -Force
Copy-Item (Join-Path $ScriptDir "Install-CoreApps.ps1")  $TempStage -Force
Copy-Item (Join-Path $ScriptDir "Start-MyWinSetup.ps1")  $TempStage -Force
Copy-Item $BundleDir $TempStage -Recurse -Force

Write-Host "OK" -ForegroundColor Green

# Show staged size
$stagedMB = [math]::Round((Get-ChildItem $TempStage -Recurse | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "  Staged: $stagedMB MB uncompressed" -ForegroundColor DarkGray

# -- Create 7z archive ---------------------------------------------------------
Write-Host "  Compressing (mx=5) ... " -NoNewline
$7zArgs = @('a', '-mx=5', '-mmt=on', $ArchivePath, "$TempStage\*")
$result = & $SevenZipExe @7zArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "7z.exe failed (exit $LASTEXITCODE):`n$result"
}
Write-Host "OK" -ForegroundColor Green

$archiveMB = [math]::Round((Get-Item $ArchivePath).Length / 1MB, 1)
Write-Host "  Archive: $archiveMB MB compressed" -ForegroundColor DarkGray

# -- Write SFX config (ASCII, no BOM) -----------------------------------------
# RunProgram runs in the extracted temp folder, so paths are relative.
# powershell -WindowStyle Hidden hides the blue console; the WPF window appears instead.
$sfxConfig = @"
;!@Install@!UTF-8!
Title="MyWin Setup"
RunProgram="powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File Start-MyWinSetup.ps1"
;!@InstallEnd@!
"@

$configPath = Join-Path $env:TEMP "sfxconfig-$(Get-Random).txt"
[System.IO.File]::WriteAllText($configPath, $sfxConfig, [System.Text.Encoding]::ASCII)

# -- Concatenate SFX module + config + archive ---------------------------------
Write-Host "  Concatenating SFX ... " -NoNewline

if (Test-Path $OutputExe) { Remove-Item $OutputExe -Force }

$outStream = [System.IO.File]::OpenWrite($OutputExe)
try {
    foreach ($src in $SfxModule, $configPath, $ArchivePath) {
        $bytes = [System.IO.File]::ReadAllBytes($src)
        $outStream.Write($bytes, 0, $bytes.Length)
    }
} finally {
    $outStream.Close()
}

Write-Host "OK" -ForegroundColor Green

$exeMB = [math]::Round((Get-Item $OutputExe).Length / 1MB, 1)
Write-Host "  Output:  $exeMB MB  ?  $OutputExe" -ForegroundColor Green

# -- Cleanup -------------------------------------------------------------------
Write-Host "  Cleaning up temp files ... " -NoNewline
Remove-Item $TempStage  -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $ArchivePath          -Force -ErrorAction SilentlyContinue
Remove-Item $configPath           -Force -ErrorAction SilentlyContinue
Write-Host "OK" -ForegroundColor Green

Write-Host ""
Write-Host "  Done: MyWin-Setup.exe ($exeMB MB)" -ForegroundColor Cyan
Write-Host "  Deploy to new machine, run as user -- GUI handles UAC elevation." -ForegroundColor DarkGray
Write-Host ""
