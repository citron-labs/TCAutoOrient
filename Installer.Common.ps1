Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TCVersions([string]$Version) {
    if ($Version -eq 'All') { return @('2024','2025','2026') }
    $items = @($Version.Split(',') | ForEach-Object { $_.Trim() } | Select-Object -Unique)
    if (!$items.Count -or @($items | Where-Object { $_ -notin @('2024','2025','2026') }).Count) {
        throw 'Select Revit 2024, 2025 or 2026 (comma-separated for multiple versions).'
    }
    return $items
}

function Get-TCRevit([string]$Version, [string]$RevitPath = '') {
    if (!$RevitPath) { $RevitPath = Join-Path $env:ProgramFiles "Autodesk/Revit $Version" }
    $RevitPath = [IO.Path]::GetFullPath($RevitPath)
    foreach ($name in @('RevitAPI.dll','RevitAPIUI.dll')) {
        $path = Join-Path $RevitPath $name
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Revit $Version API not found: $path" }
        $major = [Reflection.AssemblyName]::GetAssemblyName($path).Version.Major
        if ($major -ne ([int]$Version - 2000)) { throw "$path belongs to API version $major, not Revit $Version." }
    }
    $runtime = if ($Version -eq '2024') { 4 } else { 8 }
    $config = Join-Path $RevitPath 'RevitAPI.runtimeconfig.json'
    if ($Version -ne '2024' -and (Test-Path -LiteralPath $config)) {
        $tfm = (Get-Content -Raw -LiteralPath $config | ConvertFrom-Json).runtimeOptions.tfm
        if ($tfm -notmatch '^net(\d+)\.0$') { throw "Unrecognized Revit runtime: $tfm" }
        $runtime = [int]$Matches[1]
    }
    [pscustomobject]@{ Version=$Version; Path=$RevitPath; Runtime=$runtime }
}

function Assert-TCRevitClosed([string[]]$Versions) {
    foreach ($process in @(Get-Process Revit -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $process.Path } catch { }
        if (!$path) { throw 'Close all Revit windows before installing or uninstalling.' }
        foreach ($version in $Versions) {
            $major = [Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileMajorPart
            if ($major -eq ([int]$version - 2000) -or $path -match "Revit $version[\\/]") {
                throw "Close Revit $version (process $($process.Id)), then retry. Your open projects will not be closed automatically."
            }
        }
    }
}

function Get-TCBundledAssembly([string]$PackageRoot, [object]$Revit) {
    $folder=Join-Path $PackageRoot ('binaries/'+$Revit.Version)
    $dll=Join-Path $folder 'TCAutoOrient.dll'
    $metadata=Join-Path $folder 'build.json'
    if(!(Test-Path -LiteralPath $dll) -or !(Test-Path -LiteralPath $metadata)) {
        throw "Bundled Revit $($Revit.Version) add-in is missing. Extract the complete offline installer ZIP."
    }
    $info=Get-Content -Raw -LiteralPath $metadata | ConvertFrom-Json
    if([string]$info.revitVersion -ne $Revit.Version) { throw 'Bundled add-in version does not match the selected Revit version.' }
    if([int]$info.minimumRuntimeMajor -gt $Revit.Runtime) { throw 'The bundled add-in requires a newer runtime than this Revit installation provides.' }
    if((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -ne $info.sha256) { throw "Bundled Revit $($Revit.Version) DLL failed its integrity check. Download and extract a fresh package." }
    if([Reflection.AssemblyName]::GetAssemblyName($dll).Name -ne 'TCAutoOrient') { throw 'Unexpected bundled assembly identity.' }
    return $dll
}

function New-TCStage {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('TCAutoOrient-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Remove-TCStage([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
    if ([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notmatch '^TCAutoOrient-[a-f0-9]{32}$') {
        throw "Refusing to remove a directory outside the installer staging area: $full"
    }
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}

function Write-TCManifest([string]$Path, [string]$Assembly) {
    $xml = New-Object Xml.XmlDocument
    $root = $xml.CreateElement('RevitAddIns'); $null = $xml.AppendChild($root)
    $addin = $xml.CreateElement('AddIn'); $addin.SetAttribute('Type','Application'); $null = $root.AppendChild($addin)
    $values = [ordered]@{
        Name='TC Auto Orient'; Assembly=$Assembly; AddInId='328D85CE-C721-4877-B4DE-C4D99873A2C0'
        FullClassName='TCAutoOrient.App'; VendorId='TCOR'; VendorDescription='TC wall drop automatic labels'
    }
    foreach ($key in $values.Keys) { $node=$xml.CreateElement($key); $node.InnerText=$values[$key]; $null=$addin.AppendChild($node) }
    $xml.Save($Path)
}

function Test-TCDeployment([string]$Folder, [string]$Source) {
    $dll = Join-Path $Folder 'TCAutoOrient/TCAutoOrient.dll'
    $manifest = Join-Path $Folder 'TCAutoOrient.addin'
    if (!(Test-Path -LiteralPath $dll) -or !(Test-Path -LiteralPath $manifest)) { throw 'Installed DLL or manifest is missing.' }
    [xml]$xml = Get-Content -Raw -LiteralPath $manifest
    if ($xml.RevitAddIns.AddIn.Assembly -ne $dll -or $xml.RevitAddIns.AddIn.FullClassName -ne 'TCAutoOrient.App' -or $xml.RevitAddIns.AddIn.AddInId -ne '328D85CE-C721-4877-B4DE-C4D99873A2C0') {
        throw 'Installed manifest verification failed.'
    }
    if ((Get-FileHash -LiteralPath $dll).Hash -ne (Get-FileHash -LiteralPath $Source).Hash) { throw 'Installed DLL hash verification failed.' }
    if ([Reflection.AssemblyName]::GetAssemblyName($dll).Name -ne 'TCAutoOrient') { throw 'Unexpected installed assembly identity.' }
}

function Install-TCPayload([object[]]$Payload, [string]$Stage) {
    $records = @()
    try {
        foreach ($item in $Payload) {
            $dll = Join-Path $item.Folder 'TCAutoOrient/TCAutoOrient.dll'
            $manifest = Join-Path $item.Folder 'TCAutoOrient.addin'
            foreach ($target in @($dll,$manifest)) {
                $backup = Join-Path $Stage ([guid]::NewGuid().ToString('N') + '.backup')
                $exists = Test-Path -LiteralPath $target -PathType Leaf
                if ($exists) { Copy-Item -LiteralPath $target -Destination $backup }
                $records += [pscustomobject]@{Target=$target; Backup=$backup; Existed=$exists}
            }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dll) | Out-Null
            Copy-Item -LiteralPath $item.Source -Destination $dll -Force
            Write-TCManifest -Path $manifest -Assembly $dll
            Test-TCDeployment -Folder $item.Folder -Source $item.Source
            Write-Output "Verified Revit $($item.Version): $dll"
        }
    } catch {
        $failure = $_
        $rollbackErrors = @()
        [array]::Reverse($records)
        foreach ($record in $records) {
            try {
                if ($record.Existed) { Copy-Item -LiteralPath $record.Backup -Destination $record.Target -Force }
                elseif (Test-Path -LiteralPath $record.Target -PathType Leaf) { Remove-Item -LiteralPath $record.Target -Force }
            } catch { $rollbackErrors += $_.Exception.Message }
        }
        if ($rollbackErrors.Count) { throw "Install failed: $failure. Rollback needs attention: $($rollbackErrors -join '; ')" }
        throw "Install failed; previous DLLs and manifests restored. $failure"
    }
}

function Remove-TCInstalledFiles([string]$Folder) {
    # Only our two known files. Never recurse through a user's add-ins directory.
    $manifest=Join-Path $Folder 'TCAutoOrient.addin'
    $dll=Join-Path $Folder 'TCAutoOrient/TCAutoOrient.dll'
    foreach($path in @($manifest,$dll)) { if(Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force } }
    $directory=Split-Path -Parent $dll
    if((Test-Path -LiteralPath $directory -PathType Container) -and @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) { Remove-Item -LiteralPath $directory }
}
