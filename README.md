# TC Auto Orient - Automatic Installer v6

Extract the complete ZIP and run **Install.cmd**. Select your installed Revit
versions and click Install. If Revit is running, use **Close Revit and Retry**
and save your work when Revit prompts you.

Start Revit and open or create a project. The add-in automatically loads
**TC - Base Wall Drop AutoOrient**, synchronizes device labels, and applies any
needed zero-port visibility upgrade. No manual family loading, preparation,
ribbon panel, or Update Labels command is required. Save the project normally
to retain the loaded family and changes.

## Included updated families

- `2024/TC - Base Wall Drop AutoOrient.rfa`: supplied Revit 2024 family.
- `2025/TC - Base Wall Drop AutoOrient.rfa`: supplied Revit 2025 family.

Setup installs the matching family beside the add-in DLL. Revit 2026 uses the
supplied 2025 family and upgrades it when loading; no native 2026 family was
provided. The supplied files are packaged unchanged and verified by SHA-256.

The add-in recognizes both the new family name and the older
`TC - Base Wall Drop1` family. Existing project type values are retained when
reloading a matching family. Older placed devices remain their existing family;
the new family becomes available for placement automatically.

## Automatic behavior

The v2 number/ID position swap remains in effect. Rotating or placing devices
updates their label arrangement. A port count of zero hides the port number;
the cable ID and symbol remain visible. More than one port uses shading.

Opening projects and loading older prepared families queues setup for Revit's
next writable idle callback. Family documents are skipped. Read-only or busy
projects are deferred. A failed automatic setup reports the error in Revit;
resolve it and reopen the project to retry. Existing-family formula migrations
save a backup under `Documents/TC Auto Orient/<year>/`.

Devices with **TC Auto Orient** unchecked retain their manual layout. Grouped
devices are skipped by the rotation updater. Layout selection uses model XY,
not the rotation of each plan view. The add-in does not resolve collisions with
unrelated annotations.

## Installation details

Setup is offline and installs for the current Windows user without administrator
privileges. No .NET SDK, Visual Studio, or build is required. Separate DLLs are
included for Revit 2024 (.NET Framework 4.8) and 2025/2026 (.NET 8).

Files are installed under `%APPDATA%/Autodesk/Revit/Addins/<year>/`:

- `TCAutoOrient.addin`
- `TCAutoOrient/TCAutoOrient.dll`
- `TCAutoOrient/TC - Base Wall Drop AutoOrient.rfa`

Setup verifies DLL and family hashes and rolls back payload files if deployment
fails. Logs are under `%LOCALAPPDATA%/TCAutoOrient/SetupLogs/`.

Run **Uninstall.cmd** with Revit closed to remove the add-in. Family files and
projects are retained. The launchers use a process-only PowerShell policy
override; saved execution policies are unchanged.

Optional source build: `./install.ps1 -Version '2024,2025' -BuildFromSource`.
Only this developer mode requires a compiler and matching reference packs.

## Validation

Revit 2024/2025/2026 builds, 139 orientation checks, 13 installer checks,
8 bundled DLL/family checks, 8 simulated close-process checks, isolated
2024/2025 install/uninstall, and setup form construction passed. No live Revit
family-loading or ribbon-removal verification was performed for this release.
See `VALIDATION.txt` for details and historical results.