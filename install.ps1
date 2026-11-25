param([string]$Version='2024', [string]$RevitPath='')
. "$PSScriptRoot/Installer.Common.ps1"
$versions = @(Get-TCVersions $Version)
if ($RevitPath -and $versions.Count -ne 1) { throw 'Use -RevitPath with exactly one Revit version.' }
foreach ($v in $versions) { $null=Get-TCRevit $v $RevitPath }
Assert-TCRevitClosed $versions
$stage = New-TCStage
try {
    & "$PSScriptRoot/build.ps1" -Version ($versions -join ',') -RevitPath $RevitPath -OutputDirectory $stage
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
