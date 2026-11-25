param([switch]$SmokeTest)
. "$PSScriptRoot/Installer.Common.ps1"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='TC Auto Orient - Setup'; $form.ClientSize=New-Object Drawing.Size(600,470)
$form.StartPosition='CenterScreen'; $form.FormBorderStyle='FixedDialog'; $form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$title=New-Object Windows.Forms.Label; $title.Text='TC Auto Orient'; $title.Location=New-Object Drawing.Point(24,20); $title.Size=New-Object Drawing.Size(550,40); $title.Font=New-Object Drawing.Font('Segoe UI',22,[Drawing.FontStyle]::Bold)
$subtitle=New-Object Windows.Forms.Label; $subtitle.Text='Revit 2024 / 2025 / 2026 | Current-user setup'; $subtitle.Location=New-Object Drawing.Point(26,68); $subtitle.Size=New-Object Drawing.Size(550,26)
$heading=New-Object Windows.Forms.Label; $heading.Text='Ready to install'; $heading.Location=New-Object Drawing.Point(24,108); $heading.Size=New-Object Drawing.Size(550,32); $heading.Font=New-Object Drawing.Font('Segoe UI',15,[Drawing.FontStyle]::Bold)
$description=New-Object Windows.Forms.Label; $description.Text="Select installed Revit versions below. Close those Revit windows first.`nSetup installs the bundled add-in and verifies the files."; $description.Location=New-Object Drawing.Point(26,150); $description.Size=New-Object Drawing.Size(550,55)
$list=New-Object Windows.Forms.CheckedListBox; $list.Location=New-Object Drawing.Point(26,215); $list.Size=New-Object Drawing.Size(548,85); $list.CheckOnClick=$true
foreach($v in @('2024','2025','2026')) {
    $found=Test-Path -LiteralPath (Join-Path $env:ProgramFiles "Autodesk/Revit $v/RevitAPI.dll")
    $text=if($found){"Revit $v"}else{"Revit $v - not detected"}
    $null=$list.Items.Add($text,$found)
}
$status=New-Object Windows.Forms.Label; $status.Location=New-Object Drawing.Point(26,310); $status.Size=New-Object Drawing.Size(548,45); $status.Text='Offline installation. No .NET SDK or Visual Studio required.'
$progress=New-Object Windows.Forms.ProgressBar; $progress.Location=New-Object Drawing.Point(26,362); $progress.Size=New-Object Drawing.Size(548,18)
$install=New-Object Windows.Forms.Button; $install.Text='Install'; $install.Location=New-Object Drawing.Point(362,408); $install.Size=New-Object Drawing.Size(100,35)
$cancel=New-Object Windows.Forms.Button; $cancel.Text='Cancel'; $cancel.Location=New-Object Drawing.Point(474,408); $cancel.Size=New-Object Drawing.Size(100,35)
$logs=New-Object Windows.Forms.LinkLabel; $logs.Text='Open setup logs'; $logs.Location=New-Object Drawing.Point(26,417); $logs.Size=New-Object Drawing.Size(200,25); $logs.Visible=$false
$form.Controls.AddRange(@($title,$subtitle,$heading,$description,$list,$status,$progress,$install,$cancel,$logs))
$script:worker=$null; $script:finished=$false; $script:logFolder=$null
$timer=New-Object Windows.Forms.Timer; $timer.Interval=250
$cancel.Add_Click({$form.Close()})
$logs.Add_LinkClicked({if($script:logFolder){Start-Process explorer.exe -ArgumentList ('"'+$script:logFolder+'"')}})
$form.Add_FormClosing({param($sender,$event) if($script:worker -and !$script:worker.HasExited){$event.Cancel=$true}})
$install.Add_Click({
    if($script:finished){$form.Close();return}
    $selected=@($list.CheckedItems | ForEach-Object {if($_ -match '^Revit (\d{4})'){$Matches[1]}})
    if(!$selected.Count){$null=[Windows.Forms.MessageBox]::Show('Select at least one installed Revit version.','Select Revit');return}
    try {
        foreach($v in $selected){$null=Get-TCRevit $v}
        Assert-TCRevitClosed $selected
        $script:logFolder=Join-Path $env:LOCALAPPDATA ('TCAutoOrient/SetupLogs/'+[guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:logFolder|Out-Null
        $logs.Visible=$true; $install.Enabled=$false; $cancel.Enabled=$false; $list.Enabled=$false
        $heading.Text='Installing...'; $heading.ForeColor=[Drawing.Color]::Black
        $status.Text='Compiling against your installed Revit API. Please wait.'; $progress.Style='Marquee'
        $arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "'+(Join-Path $PSScriptRoot 'install.ps1')+'" -Version "'+($selected -join ',')+'"'
        $script:worker=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $script:logFolder 'output.log') -RedirectStandardError (Join-Path $script:logFolder 'error.log')
        $null=$script:worker.Handle
        $timer.Start()
    } catch {
        $install.Enabled=$true; $install.Text='Retry'; $cancel.Enabled=$true; $list.Enabled=$true
        $heading.Text='Setup needs attention'; $progress.Style='Blocks'; $progress.Value=0
        $null=[Windows.Forms.MessageBox]::Show($_.Exception.Message,'TC Auto Orient - Setup','OK','Warning')
    }
})
$timer.Add_Tick({
    if(!$script:worker -or !$script:worker.HasExited){return}
    $timer.Stop(); $script:worker.WaitForExit(); $progress.Style='Blocks'
    $install.Enabled=$true; $cancel.Enabled=$true
    if($script:worker.ExitCode -eq 0){
        $heading.Text='Installed successfully!'; $heading.ForeColor=[Drawing.Color]::ForestGreen
        $progress.Value=100; $status.Text='DLL and registration verified. Start Revit to use TC Auto Orient.'
        $install.Text='Finish'; $cancel.Visible=$false; $script:finished=$true
    }else{
        $heading.Text='Installation failed'; $heading.ForeColor=[Drawing.Color]::Firebrick
        $status.Text='Open setup logs for details. Correct the problem, then retry.'
        $install.Text='Retry'; $list.Enabled=$true
        $errorText=Get-Content -Raw -LiteralPath (Join-Path $script:logFolder 'error.log') -ErrorAction SilentlyContinue
        if(!$errorText){$errorText='Installation failed. See setup logs.'}
        $null=[Windows.Forms.MessageBox]::Show($errorText,'TC Auto Orient - Setup','OK','Error')
    }
    $script:worker.Dispose(); $script:worker=$null
})
try {
    if($SmokeTest){$form.CreateControl();Write-Output "Setup form constructed: $($list.Items.Count) version choices; $($list.CheckedItems.Count) detected."}
    else {$null=$form.ShowDialog()}
} finally {$timer.Dispose();$form.Dispose()}
