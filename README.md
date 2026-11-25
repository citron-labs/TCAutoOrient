# TC Auto Orient - Offline Installer

Extract the entire **TC-Auto-Orient-Offline-Installer.zip**, close Revit, and double-click **Install.cmd**. Select Revit 2024, 2025 or 2026 and click Install.

This package contains a separately compiled add-in for each Revit version. Normal setup requires **no .NET SDK, Visual Studio, compilation, or Internet download**. Revit must already be installed. Revit 2024 uses the bundled .NET Framework 4.8 build; 2025/2026 use their respective .NET 8 builds.

Setup installs for the current Windows account without administrator privileges. It verifies bundled DLL hashes, stages all selected versions, and backs up existing files before deployment. A deployment failure restores previous files. Setup logs are under %LOCALAPPDATA%/TCAutoOrient/SetupLogs/.

Installed files are under %APPDATA%/Autodesk/Revit/Addins/<year>/:
- TCAutoOrient.addin
- TCAutoOrient/TCAutoOrient.dll

Double-click **Uninstall.cmd** to remove the add-in. Families, projects and unrelated files are preserved. Close Revit before installation, updates or removal.

The launchers use a process-only PowerShell execution-policy override; saved policies are unchanged and organizational Group Policy takes precedence.

For a custom Revit location:
```powershell
./install.ps1 -Version 2025 -RevitPath 'D:/Autodesk/Revit 2025'
```

## Installer architecture

Install.cmd -> InstallWindow.ps1 -> install.ps1 -> verified bundled DLL + .addin

Source compilation remains an optional developer operation:
```powershell
./install.ps1 -Version '2024,2025' -BuildFromSource
```
Only this optional mode requires the local compiler/reference packs matching the installed Revit runtime (including SDK 10 when Revit uses .NET 10). Normal graphical setup never invokes it.

## Included family and demonstration projects

- `deliverables/2024/TC - Base Wall Drop1.rfa`: prepared device family.
- `deliverables/2024/TC_WALL DROP SYMBOL.rfa`: its edited nested annotation.
- `deliverables/2024/TC Wall Drop1 - Auto Orient Demo.rvt`: five-device example.
- `deliverables/2025/`: native 2025 parent family and example project.
- `backup/`: original family before editing.
- `verification/`: short/long label previews and previous live add-in test results.

Revit 2026 can upgrade the 2024/2025 family and project. A native-2026-saved model
is not included. Load the parent family for device placement; the annotation is
already embedded inside it.

## Formatting behavior

Leave **TC Auto Orient** checked on the device. Rotating or placing it selects one
of four cardinal label arrangements: number above the cable ID for side layouts,
and number left of the cable ID for top/bottom layouts. One port has no shading;
more than one port uses the original shaded half. Long cable IDs grow outward,
away from the number and symbol, with direction-specific alignment.

**Add-Ins ? TC Auto Orient ? Update Labels** updates existing prepared devices.
**Prepare Wall Drop1** prepares this specific parent family in the family editor or
project, including a backup when run in a project. Its expected name is
`TC - Base Wall Drop1`, with the supplied parameter names and nested symbol.

Uncheck **TC Auto Orient** to choose **TC Label Quadrant** manually: 0 north,
1 east, 2 south, 3 west. Angled devices choose the nearest quadrant; text uses Revit's
Keep Readable behavior. Quadrants refer to model XY, not each rotated plan view.
Grouped devices are skipped by the updater. This tool does not resolve collisions
with unrelated annotations. Without the add-in, the family retains its last layout
but no longer reacts automatically to rotations.

## Validation

See VALIDATION.txt. Installation and removal are tested in isolated user-data directories for installed Revit 2024/2025. Revit 2026 compiled successfully and its payload deployment was tested in isolation; startup and model behavior in Revit 2026 remain untested.

```powershell
./tests/Installer.Tests.ps1
./tests/Bundled.Tests.ps1
./tests/Installer.EndToEnd.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ./InstallWindow.ps1 -SmokeTest
```

## Sharing

Share the complete ZIP via a Drive download link if Gmail blocks the executable attachments. See SHARING.txt.