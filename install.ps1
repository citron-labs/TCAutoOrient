param([string]$Version='2024', [string]$RevitPath='', [switch]$BuildFromSource)
. "$PSScriptRoot/Installer.Common.ps1"
$versions = @(Get-TCVersions $Version)
if ($RevitPath -and $versions.Count -ne 1) { throw 'Use -RevitPath with exactly one Revit version.' }
$revitInstalls = @($versions | ForEach-Object { Get-TCRevit $_ $RevitPath })
Assert-TCRevitClosed $versions
$stage = New-TCStage
try {
    if ($BuildFromSource) {
        & "$PSScriptRoot/build.ps1" -Version ($versions -join ',') -RevitPath $RevitPath -OutputDirectory $stage
    } else {
        foreach ($revit in $revitInstalls) {
            $source = Get-TCBundledAssembly -PackageRoot $PSScriptRoot -Revit $revit
            $dest = Join-Path $stage $revit.Version
            New-Item -ItemType Directory -Path $dest | Out-Null
            Copy-Item -LiteralPath $source -Destination (Join-Path $dest 'TCAutoOrient.dll')
            Write-Output "Using verified bundled add-in for Revit $($revit.Version). No SDK required."
        }
    }
    Assert-TCRevitClosed $versions
    $payload = @($versions | ForEach-Object {
        [pscustomobject]@{Version=$_;Source=(Join-Path $stage "$_/TCAutoOrient.dll");Folder=(Join-Path $env:APPDATA "Autodesk/Revit/Addins/$_")}
    })
    Install-TCPayload -Payload $payload -Stage $stage
    Remove-TCStage $stage
    Write-Output 'Installed successfully! Start Revit to load TC Auto Orient.'
} catch {
    Write-Output "Installation did not complete. Diagnostic staging files retained at: $stage"
    throw
}
