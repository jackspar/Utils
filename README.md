# jackspar/Utils

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue?logo=windows)](https://github.com/jackspar/Utils)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://github.com/jackspar/Utils)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Windows PowerShell utilities. Run from anywhere — no install needed.

---

## Cleanup-Windows.ps1

Interactive disk cleanup — scans sizes, shows a menu, runs only what you pick.

```powershell
irm https://raw.githubusercontent.com/jackspar/Utils/master/Cleanup-Windows.ps1 | iex
```

Cleans: Windows Temp, User Temp, Update Cache, Prefetch, Event Logs, Disk Cleanup (22 cat), DISM.
Does **not** touch browser caches.

---

## MyApps-Setup.ps1

Installs 33 standard desktop apps on a fresh PC via an interactive checkbox menu (winget + GitHub releases).

```powershell
irm https://raw.githubusercontent.com/jackspar/Utils/master/MyApps-Setup.ps1 | iex
```

Covers: Shell/UI, Browsers, Hardware monitors, File/Disk, Dev tools, Media, Utilities, Gaming.
Reminds you of manual-only installs (NinjaTrader 8, thinkorswim, Office 2010, Epson Scan 2).

---

## Requirements

- Windows 10 22H2+ or Windows 11
- PowerShell 5.1 (built-in)
- `winget` (built into Windows 10 22H2+ / Windows 11)

---

[MIT License](LICENSE)
