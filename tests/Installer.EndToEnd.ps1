# Runs real build/install/uninstall scripts in an isolated user-data directory.
# Only process discovery is mocked; no live Revit registration is modified.
param([string]$Version='2024,2025')
. "$PSScriptRoot/../Installer.Common.ps1"
$testRoot=New-TCStage
$originalAppData=$env:APPDATA
function Get-Process { param([string]$Name) return @() }
try {
    $env:APPDATA=Join-Path $testRoot 'AppData'
    & "$PSScriptRoot/../install.ps1" -Version $Version
    foreach($v in @(Get-TCVersions $Version)) {
        $manifest=Join-Path $env:APPDATA "Autodesk/Revit/Addins/$v/TCAutoOrient.addin"
        if(!(Test-Path -LiteralPath $manifest)){throw "Missing $v registration"}
        [xml]$xml=Get-Content -Raw -LiteralPath $manifest
        if(!(Test-Path -LiteralPath $xml.RevitAddIns.AddIn.Assembly)){throw "Missing $v DLL"}
    }
    & "$PSScriptRoot/../Uninstall.ps1" -Version $Version -ConfirmRemoval
    if(@(Get-ChildItem -LiteralPath $env:APPDATA -Filter 'TCAutoOrient.addin' -Recurse).Count){throw 'Uninstall failed'}
    Write-Output 'End-to-end local compile, deployment and uninstall passed in isolated AppData.'
} finally {
    $env:APPDATA=$originalAppData
    Remove-TCStage $testRoot
}
