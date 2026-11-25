# TC Auto Orient ? Source Installer

Double-click **Install.cmd** after extracting this entire folder. Setup builds
TC Auto Orient against your installed Revit API and installs it for your Windows
account. No precompiled add-in DLL or Autodesk API DLL is included in this package.

## Install

1. Extract **all** files from `TC-Auto-Orient-Source-Installer.zip`.
2. Save your work and close the Revit versions you want to install into.
3. Open the extracted `TC-Auto-Orient` folder and double-click **Install.cmd**.
4. Select the installed Revit versions and click **Install**.
5. Wait for **Installed successfully!**, click **Finish**, and start Revit.

The graphical setup shows progress and offers Retry and setup logs on failure.
It does not close Revit automatically. Administrative privileges are not requested.
The launcher does not override PowerShell execution policy. If your organization's
policy blocks scripts, use its approved installation process.

### Prerequisites

| Revit version | Local build requirements |
| --- | --- |
| 2024 | Installed Revit 2024 API and Windows .NET Framework 4.8 x64 compiler; no .NET SDK or Visual Studio required |
| 2025 / 2026 | Installed matching Revit API, an x64 .NET SDK and matching reference pack |

The installer reads the installed Revit runtime configuration. Standard .NET 8
installations need the .NET 8 reference pack; an updated Revit using .NET 10 needs
the .NET 10 pack. These packs normally come with the corresponding SDK. Setup
reports missing prerequisites instead of downloading them.

Default API locations are `C:/Program Files/Autodesk/Revit <year>/`. For a custom
location, use the command-line installer with exactly one version:

```powershell
./install.ps1 -Version 2024 -RevitPath 'D:/Autodesk/Revit 2024'
```

Multiple versions can be selected in the window or specified as a quoted list:

```powershell
./install.ps1 -Version '2024,2025'
```

Select 2026 only on a machine with Revit 2026 installed.

## Installer architecture

`Install.cmd` ? `InstallWindow.ps1` ? `install.ps1` ? `build.ps1` ? DLL + `.addin`

The build uses C# 5-compatible source and the local Revit assemblies. Revit 2024
uses Windows' built-in Framework compiler; newer versions use the SDK's Roslyn
compiler with local reference packs. There is no NuGet restore, network download,
background service or Autodesk program-file modification in this workflow.

All selected versions compile in a unique temporary staging directory before any
installed files are replaced. Deployment backs up existing DLLs/manifests,
verifies XML, assembly identity, absolute paths and SHA-256 content, and restores
previous files if deployment fails. Failed staging files are retained for diagnosis;
successful staging files are cleaned up.

Installed files:

```text
%APPDATA%/Autodesk/Revit/Addins/<year>/
  TCAutoOrient.addin
  TCAutoOrient/TCAutoOrient.dll
```

Setup logs are under `%LOCALAPPDATA%/TCAutoOrient/SetupLogs/`. Re-running Install
updates or repairs the same registration. Close Revit before updates. Double-click
**Uninstall.cmd** to remove the add-in; families, projects and unrelated files are kept.

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

## Testing and development

See **VALIDATION.txt** for verified behavior and remaining limits. Local installer
builds and isolated deployment tests pass for installed Revit 2024 and 2025.
Revit 2026 is not installed here, so its new local build/install path is untested.
The previously delivered add-in passed 23 live checks in each of 2024 and 2025.

```powershell
./build.ps1 -Version '2024,2025'
./tests/Installer.Tests.ps1
./tests/Installer.EndToEnd.ps1
powershell.exe -NoProfile -STA -File ./InstallWindow.ps1 -SmokeTest
dotnet run --project tests/OrientationTests.csproj -c Release
```

Standalone build output goes under `artifacts/local/<year>`. The optional root
`TCAutoOrient.csproj` supports IDE development; the installer compiles directly
without MSBuild or project restore. For an updated runtime, IDE builds can use
`-p:RuntimeTarget=net10.0-windows -p:RevitVersion=2025`.

## Sharing through Gmail

Gmail may still block this ZIP because it contains `.cmd` launchers and PowerShell
scripts, even without DLLs. Upload the full ZIP to Google Drive and send a link to
the intended recipient. See **SHARING.txt** and
[Google's attachment guidance](https://support.google.com/mail/answer/6590/).
