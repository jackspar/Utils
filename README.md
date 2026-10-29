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
| [MyApps-Setup.ps1](#myapps-setupps1) | Install standard desktop apps on a new PC |

---

## Cleanup-Windows.ps1

Generic Windows routine cleanup. Scans folder sizes first, shows an interactive menu with estimates, then runs only what you select.

### Run from anywhere (no install needed)

```powershell
irm https://raw.githubusercontent.com/jackspar/Utils/master/Cleanup-Windows.ps1 | iex
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

### What it does NOT touch

- Browser caches (Brave, Firefox, Chrome, Edge)
- User documents, downloads, or application data
- Any installed application data

---

## MyApps-Setup.ps1

Installs a standard desktop app set on a fresh Windows 10/11 PC using an interactive checkbox menu. Uses `winget` for most apps and GitHub releases API for ExplorerPatcher and Open Shell.

### Run from anywhere (no install needed)

```powershell
irm https://raw.githubusercontent.com/jackspar/Utils/master/MyApps-Setup.ps1 | iex
```

Or run a local copy:

```powershell
powershell -ExecutionPolicy Bypass -File MyApps-Setup.ps1
```

> Auto-elevates to Administrator. Requires `winget` (built into Windows 10 22H2+ and Windows 11).

### Apps included (33 total)

| Category | App | Method |
|---|---|---|
| Shell/UI | ExplorerPatcher | GitHub release |
| Shell/UI | Open Shell | GitHub release |
| Shell/UI | Microsoft PowerToys | winget |
| Shell/UI | 8GadgetPack | Local MSI only (v31) |
| Browser | Brave Browser | winget |
| Browser | Firefox | winget |
| Hardware | HWiNFO 64 | winget |
| Hardware | Core Temp | winget |
| Hardware | CPU-Z | winget |
| Hardware | CrystalDiskMark | winget |
| File/Disk | Everything | winget |
| File/Disk | WizTree | winget |
| File/Disk | WinDirStat | winget |
| File/Disk | 7-Zip | winget |
| Cloud | Google Drive | winget |
| Dev | Visual Studio Code | winget |
| Dev | Node.js LTS | winget |
| Dev | Deno | winget |
| Dev | uv | winget |
| Dev | git | winget |
| Dev | gh CLI | winget |
| Media | OBS Studio | winget |
| Media | Audacity | winget |
| Media | FFmpeg | winget |
| Media | yt-dlp | winget |
| Media | Foxit PDF Reader | winget |
| Utility | Macrium Reflect Free | winget |
| Utility | Wise Program Uninstaller | winget |
| Utility | Zoom | winget |
| Utility | Messenger | winget |
| Gaming | NVIDIA GeForce NOW | winget |
| Gaming | Steam | winget |
| Gaming | Epic Games Launcher | winget |
| App | Canva | winget |

### Manual installs (cannot be automated)

The script displays these reminders after install:

- **NinjaTrader 8** — ninjatrader.com (requires account)
- **thinkorswim** — schwab.com/trading/thinkorswim (requires account)
- **Office 2010** — from install media
- **Epson Scan 2** — epson.com (printer-specific driver)

### 8GadgetPack note

8GadgetPack installs from a local MSI copy only (v31). If the MSI is not found on your D: drive, the script will display an error — it does **not** download a newer version, as newer versions may omit gadgets from an existing configuration.

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 (built-in) or later
- Internet connection for the `irm | iex` one-liners and winget installs
- `winget` required for MyApps-Setup (built into Windows 10 22H2+ and Windows 11)

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.
