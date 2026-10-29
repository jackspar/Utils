# jackspar/Utils

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue?logo=windows)](https://github.com/jackspar/Utils)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://github.com/jackspar/Utils)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Public Windows utilities. Run any script on any PC — **no installation required**.

---

## Scripts

| Script | Description |
|---|---|
| [Cleanup-Windows.ps1](#cleanup-windowsps1) | Interactive disk cleanup with space estimates |

---

## Cleanup-Windows.ps1

Generic Windows routine cleanup. Scans folder sizes first, shows an interactive menu with estimates, then runs only what you select.

### Run from anywhere (no install needed)

```powershell
irm https://raw.githubusercontent.com/jackspar/Utils/main/Cleanup-Windows.ps1 | iex
```

Or run a local copy:

```powershell
powershell -ExecutionPolicy Bypass -File Cleanup-Windows.ps1
```

> Auto-elevates to Administrator. Safe to run on any Windows 10/11 PC.

### What it cleans

| # | Item | Notes |
|---|---|---|
| 1 | Windows Temp | `C:\Windows\Temp` |
| 2 | User Temp | `%LOCALAPPDATA%\Temp` |
| 3 | Windows Update Cache | `C:\Windows\SoftwareDistribution\Download` |
| 4 | Prefetch Cache | `C:\Windows\Prefetch` |
| 5 | Event Viewer Logs | All Windows event logs via `wevtutil` |
| 6 | Disk Cleanup (22 categories) | Runs `cleanmgr` with full category set |
| 7 | DISM Component Store | `/StartComponentCleanup` — takes 5-15 min, reboot recommended |

### Interactive menu

```
  ============================================================
   CLEANUP-WINDOWS
   2026-10-29 10:00   |   C: free: 22.4 GB
  ============================================================

  Select items to clean  (number to toggle, ENTER to run, Q to quit)
  A = Select All   N = Select None

  [X] 1. Windows Temp            ~125 MB
  [X] 2. User Temp (JR)          ~ 45 MB
  [X] 3. Windows Update Cache    ~ 18 MB
  [X] 4. Prefetch Cache          ~  8 MB
  [X] 5. Event Viewer Logs       ~250 MB
  [X] 6. Disk Cleanup (22 cat)   ~varies (slow)
  [X] 7. DISM Component Store    ~varies (slow)
```

All items are selected by default. Press a number to toggle, `A`/`N` to select all or none, then `Enter` to run.

### What it does NOT touch

- Browser caches (Brave, Firefox, Chrome, Edge)
- User documents, downloads, or application data
- Any installed application data

### After running

A summary shows total space freed and a log line is written to `cleanup_log.txt` in the script directory. A reboot is recommended if DISM was selected.

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 (built-in) or later
- Internet connection only needed for the `irm | iex` one-liner

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.