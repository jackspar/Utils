# jackspar/utils

Public Windows utilities — run on any PC without installing anything.

## Cleanup-Windows.ps1

Generic Windows routine cleanup with an interactive menu. Shows estimated space for each category before you run anything.

**Cleans:** Windows Temp · User Temp · Windows Update Cache · Prefetch · Event Logs · Disk Cleanup (22 categories) · DISM Component Store

### Run from anywhere (no install needed)

```powershell
irm https://raw.githubusercontent.com/jackspar/utils/main/Cleanup-Windows.ps1 | iex
```

Or download and run locally:

```powershell
powershell -ExecutionPolicy Bypass -File Cleanup-Windows.ps1
```

### What it looks like

```
  ====================================================
   CLEANUP-WINDOWS
   2026-10-29 10:00   |   C: free: 22.4 GB
  ====================================================

  Select items to clean  (number to toggle, ENTER to run, Q to quit)
  A = Select All   N = Select None

  [X] 1. Windows Temp           ~125 MB
  [X] 2. User Temp (JR)         ~ 45 MB
  [X] 3. Windows Update Cache   ~ 18 MB
  [X] 4. Prefetch Cache         ~  8 MB
  [X] 5. Event Viewer Logs      ~250 MB
  [X] 6. Disk Cleanup (22 cat)  ~varies (slow)
  [X] 7. DISM Component Store   ~varies (slow)
```

Toggle items on/off with number keys · DISM takes 5–15 min and needs a reboot · auto-elevates to Admin

### Safe for Windows 10 / 11 — does not touch browser caches, user documents, or application data
