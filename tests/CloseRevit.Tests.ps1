. "$PSScriptRoot/../Installer.Common.ps1"
$checks=0
function Check([bool]$Value,[string]$Message){if(!$Value){throw $Message};$script:checks++}
# Fake processes only. No live Revit window receives a close request.
function New-FakeRevit([int]$ProcessId,[string]$Version,[bool]$CanClose=$true) {
    $fake=[pscustomobject]@{Id=$ProcessId;Path=(Join-Path $env:ProgramFiles "Autodesk/Revit $Version/Revit.exe");CloseRequests=0;CanClose=$CanClose}
    $fake | Add-Member -MemberType ScriptMethod -Name CloseMainWindow -Value {$this.CloseRequests++;return $this.CanClose}
    return $fake
}
function Get-Process {param([string]$Name) return $script:fakeProcesses}
$selected=New-FakeRevit 101 '2025'
$unselected=New-FakeRevit 102 '2024'
$script:fakeProcesses=@($selected,$unselected)
Check (@(Get-TCBlockingRevitProcesses @('2025')).Count -eq 1) 'Unselected versions must not block.'
$blocked=$false;try{Assert-TCRevitClosed @('2025')}catch{$blocked=$true}
Check $blocked 'Installation must remain blocked while Revit runs.'
Request-TCRevitClose @('2025')
Check ($selected.CloseRequests -eq 1) 'Selected Revit did not receive a normal close request.'
Check ($unselected.CloseRequests -eq 0) 'Unselected Revit received a close request.'
$blocked=$false;try{Assert-TCRevitClosed @('2025')}catch{$blocked=$true}
Check $blocked 'A close request must not be treated as an exited process.'
$script:fakeProcesses=@($unselected)
Assert-TCRevitClosed @('2025')
Check (@(Get-TCBlockingRevitProcesses @('2025')).Count -eq 0) 'Exited Revit must unblock installation.'
$noWindow=New-FakeRevit 103 '2025' $false
$script:fakeProcesses=@($noWindow)
$failed=$false;try{Request-TCRevitClose @('2025')}catch{$failed=$true}
Check $failed 'A failed normal close must report that manual closure is required.'
$unknown=[pscustomobject]@{Id=104;Path=$null}
$script:fakeProcesses=@($unknown)
$failed=$false;try{Request-TCRevitClose @('2025')}catch{$failed=$true}
Check $failed 'An unidentified process must not be closed.'
Write-Output "$checks close-and-retry checks passed. No live processes were closed."
