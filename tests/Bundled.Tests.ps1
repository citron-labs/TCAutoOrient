. "$PSScriptRoot/../Installer.Common.ps1"
$stage=New-TCStage
$checks=0
try {
    Copy-Item -LiteralPath "$PSScriptRoot/../binaries" -Destination $stage -Recurse
    foreach($year in @('2024','2025','2026')) {
        $runtime=if($year -eq '2024'){4}else{8}
        $dll=Get-TCBundledAssembly $stage ([pscustomobject]@{Version=$year;Runtime=$runtime})
        $folder=Join-Path $stage "Addins/$year"
        Install-TCPayload @([pscustomobject]@{Version=$year;Source=$dll;Folder=$folder}) $stage
        Test-TCDeployment $folder $dll
        $checks++
    }
    $null=Get-TCBundledAssembly $stage ([pscustomobject]@{Version='2025';Runtime=10});$checks++
    $failed=$false
    try {$null=Get-TCBundledAssembly $stage ([pscustomobject]@{Version='2025';Runtime=7})}catch{$failed=$true}
    if(!$failed){throw 'Runtime mismatch accepted'};$checks++
    $meta=Join-Path $stage 'binaries/2025/build.json'
    $info=Get-Content -Raw $meta|ConvertFrom-Json
    $info.revitVersion='2026';$info|ConvertTo-Json|Set-Content $meta
    $failed=$false
    try {$null=Get-TCBundledAssembly $stage ([pscustomobject]@{Version='2025';Runtime=8})}catch{$failed=$true}
    if(!$failed){throw 'Version mismatch accepted'};$checks++
    [IO.File]::AppendAllText((Join-Path $stage 'binaries/2024/TCAutoOrient.dll'),'corrupt')
    $failed=$false
    try {$null=Get-TCBundledAssembly $stage ([pscustomobject]@{Version='2024';Runtime=4})}catch{$failed=$true}
    if(!$failed){throw 'Corrupt binary accepted'};$checks++
    Write-Output "$checks bundled payload checks passed. Revit 2026 deployment is simulated, not live-tested."
} finally {Remove-TCStage $stage}
