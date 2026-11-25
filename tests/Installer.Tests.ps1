param([string]$BuiltDll=(Join-Path $PSScriptRoot '../binaries/2024/TCAutoOrient.dll'))
. "$PSScriptRoot/../Installer.Common.ps1"
$stage=New-TCStage
$checks=0
function Check([bool]$Value,[string]$Message){if(!$Value){throw $Message};$script:checks++}
try {
    Check ((Get-TCVersions '2024,2025,2024').Count -eq 2) 'Version normalization failed.'
    $invalid=$false;try{$null=Get-TCVersions '2027'}catch{$invalid=$true};Check $invalid 'Invalid version accepted.'
    $folder=Join-Path $stage 'User profile & test/Addins/2024'
    $payload=@([pscustomobject]@{Version='2024';Source=[IO.Path]::GetFullPath($BuiltDll);Folder=$folder})
    Install-TCPayload $payload $stage
    Test-TCDeployment $folder $BuiltDll
    Check (Test-Path -LiteralPath (Join-Path $folder 'TCAutoOrient.addin')) 'Manifest missing.'
    $beforeDll=(Get-FileHash -LiteralPath (Join-Path $folder 'TCAutoOrient/TCAutoOrient.dll')).Hash
    $beforeManifest=[IO.File]::ReadAllBytes((Join-Path $folder 'TCAutoOrient.addin'))
    # Force failure in a second destination after the first destination was replaced.
    $bad=Join-Path $stage 'blocked';[IO.File]::WriteAllText($bad,'This path is a file, not a directory.')
    $failed=$false
    try {Install-TCPayload @($payload[0],[pscustomobject]@{Version='2025';Source=$BuiltDll;Folder=$bad}) $stage}catch{$failed=$true}
    Check $failed 'Expected deployment failure was not detected.'
    Check ((Get-FileHash -LiteralPath (Join-Path $folder 'TCAutoOrient/TCAutoOrient.dll')).Hash -eq $beforeDll) 'Rollback did not restore DLL.'
    Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $folder 'TCAutoOrient.addin'))) -eq [Convert]::ToBase64String($beforeManifest)) 'Rollback did not restore manifest.'
    Install-TCPayload $payload $stage
    $keep=Join-Path $folder 'unrelated.addin';[IO.File]::WriteAllText($keep,'keep')
    $extra=Join-Path $folder 'TCAutoOrient/keep.txt';[IO.File]::WriteAllText($extra,'keep')
    Remove-TCInstalledFiles $folder
    Check (!(Test-Path -LiteralPath (Join-Path $folder 'TCAutoOrient.addin'))) 'Uninstall left manifest.'
    Check (!(Test-Path -LiteralPath (Join-Path $folder 'TCAutoOrient/TCAutoOrient.dll'))) 'Uninstall left DLL.'
    Check ((Test-Path -LiteralPath $keep) -and (Test-Path -LiteralPath $extra)) 'Uninstall removed unrelated data.'
    $refused=$false;try{Remove-TCStage (Split-Path -Parent $stage)}catch{$refused=$true};Check $refused 'Cleanup accepted an unsafe target.'
    Write-Output "$checks installer checks passed (fresh install, reinstall, rollback, manifest escaping, uninstall, cleanup)."
} finally {Remove-TCStage $stage}
