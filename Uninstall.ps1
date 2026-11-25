param([string]$Version='All', [switch]$ConfirmRemoval)
. "$PSScriptRoot/Installer.Common.ps1"
$versions = @(Get-TCVersions $Version)
if (!$ConfirmRemoval) {
    Add-Type -AssemblyName System.Windows.Forms
    $answer=[Windows.Forms.MessageBox]::Show("Remove TC Auto Orient from Revit $($versions -join ', ')?`n`nFamily files and projects will be kept.",'TC Auto Orient - Uninstall','YesNo','Question')
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
}
try {
    Assert-TCRevitClosed $versions
    foreach ($v in $versions) { Remove-TCInstalledFiles (Join-Path $env:APPDATA "Autodesk/Revit/Addins/$v") }
    Write-Output 'TC Auto Orient removed. Families and projects were kept.'
    if (!$ConfirmRemoval) { $null=[Windows.Forms.MessageBox]::Show('TC Auto Orient removed. Families and projects were kept.','Uninstall complete') }
} catch {
    if (!$ConfirmRemoval) { $null=[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Uninstall failed','OK','Error') }
    throw
}
