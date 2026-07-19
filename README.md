# Windows Update Remediation Tool

Automated Windows Update remediation utility with a modern WinForms GUI. The tool stops update services, clears update caches and queues, resets service permissions, re-registers common update-related DLLs, resets Winsock, restarts services, triggers a scan and produces diagnostics using SetupDiag.

## Quick start

1. Open an elevated PowerShell (Run as Administrator).
2. From the folder containing the script run:

   - PowerShell (recommended):
     ```powershell
     PowerShell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-WindowsUpdateRemediation.ps1
     ```
   - Or double-click the script from Explorer while running PowerShell as Administrator.

## Requirements

- Windows (the script uses WinForms / System.Drawing).
- PowerShell 5.1+ or PowerShell 7+ on Windows.
- Administrator privileges (the script will show a message and exit if not elevated).
- Internet access (only required for downloading SetupDiag in the diagnostics step).

If your execution policy prevents running the script temporarily:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

## What it does (10 selectable steps)

1. Policy Cleanup — clears Windows Update-related policy registry entries.
2. Stop Services — stops BITS, wuauserv and cryptsvc.
3. QMGR Cleanup — removes corrupted Background Intelligent Transfer Service queue files.
4. Cache Cleanup — deletes SoftwareDistribution and Catroot2 folders.
5. Service Permissions — resets service security descriptors via sc.exe sdset.
6. DLL Registration — re-registers ~36 common Windows DLLs used by update components.
7. Winsock Reset — runs `netsh winsock reset`.
8. Start Services — starts BITS, wuauserv and cryptsvc.
9. Update Scan — triggers `USOClient.exe StartInteractiveScan` and waits ~5 minutes.
10. SetupDiag Diagnostics — downloads `SetupDiag.exe` and creates a diagnostic log in the log folder.

You can select which steps to run via the UI. "Select All" / "Deselect All" are provided.

## UI features / shortcuts

- Buttons: Select All, Deselect All, Start All, Stop, Open Log File, Close, Open SetupDiag Log.
- Progress UI with per-step state (Running / Completed / Error).
- Keyboard shortcuts:
  - F5 — Start
  - Esc — Stop (or Close if idle)
  - Ctrl+L — Open log file

## Logs

- Default log directory: `C:\Temp`
- Main log file: `C:\Temp\WinUpdate_Remediation.log`
- SetupDiag is downloaded to: `C:\Temp\SetupDiag.exe`
- SetupDiag output: `C:\Temp\#Windows Updates - Diagnostics.log`

The UI appends timestamped entries to both the on-screen log and the file above.

## Safety & notes (important)

- Requires Administrator. Do not run on machines where you cannot afford configuration changes without approval.
- The script deletes `SoftwareDistribution` and `Catroot2` folders and removes/updates registry keys — these are standard remediation steps but are potentially disruptive. Back up important data or create a system restore point if required by your environment.
- Service permission resets and `regsvr32` calls are low-level operations. Use with caution on heavily managed or enterprise-locked systems (SCCM/Intune/Group Policy).
- The tool will prompt before running selected steps. A Restart is recommended after completion.
- The script uses Try/Catch for error counting and logs errors; however, complex environments may require manual follow-up.

## Troubleshooting

- If SetupDiag download or run fails, check internet access and that `C:\Temp` (or configured log folder) is writable.
- If services fail to start/stop, check Group Policy, service dependencies, and event logs.
- If the GUI does not render, ensure Windows and .NET/WinForms support are available for your PowerShell host.

## Example run

- Elevated, bypass execution policy and run:

```powershell
PowerShell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-WindowsUpdateRemediation.ps1
```

## License

- Default: MIT. Update as needed (no license file included by default).

## Author / Support

- Author: Mert Ozsoy  
  Website: https://mertozsoy.com/  
  GitHub: https://github.com/mertozsoy

Report issues: https://github.com/mertozsoy/WindowsUpdateRemedationTool/issues
