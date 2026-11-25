param([string]$Version='All', [string]$RevitPath='', [string]$OutputDirectory='')
. "$PSScriptRoot/Installer.Common.ps1"
$versions = @(Get-TCVersions $Version)
if ($RevitPath -and $versions.Count -ne 1) { throw 'Use -RevitPath with exactly one Revit version.' }
foreach ($v in $versions) {
    $revit = Get-TCRevit $v $RevitPath
    $sources = @(Get-ChildItem -LiteralPath "$PSScriptRoot/src" -Filter '*.cs' -File)
    if (!$sources.Count) { throw 'The src folder is missing or empty. Extract the complete ZIP before installing.' }
    $out = if ($OutputDirectory) { Join-Path $OutputDirectory $v } else { Join-Path $PSScriptRoot "artifacts/local/$v" }
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $dll = Join-Path $out 'TCAutoOrient.dll'
    $references = @((Join-Path $revit.Path 'RevitAPI.dll'), (Join-Path $revit.Path 'RevitAPIUI.dll'))
    $compilerArgs = @('/nologo','/target:library','/platform:x64','/optimize+','/nostdlib+',('/out:"'+$dll+'"'))
    if ($v -eq '2024') {
        $framework = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
        $compiler = Join-Path $framework 'csc.exe'
        if (!(Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework x64 C# compiler is missing. Install/repair .NET Framework 4.8.' }
        foreach ($name in @('mscorlib.dll','System.dll','System.Core.dll')) { $references += Join-Path $framework $name }
    } else {
        $dotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue
        if (!$dotnet) { throw "Install the .NET $($revit.Runtime) SDK (x64), then retry. Visual Studio is not required." }
        $sdks = @(& $dotnet.Source --list-sdks | ForEach-Object {
            if ($_ -match '^(\d+\.\d+\.\d+)\s+\[(.+)\]$') { [pscustomobject]@{ Version=[version]$Matches[1]; Root=$Matches[2] } }
        } | Where-Object {$_.Version.Major -ge $revit.Runtime} | Sort-Object Version -Descending)
        if (!$sdks.Count) { throw "A .NET SDK version $($revit.Runtime) or later is required for this Revit installation." }
        $sdk = $sdks[0]
        $compiler = Join-Path $sdk.Root "$($sdk.Version)/Roslyn/bincore/csc.dll"
        $packs = Join-Path (Split-Path -Parent $sdk.Root) 'packs/Microsoft.NETCore.App.Ref'
        $pack = @(Get-ChildItem -LiteralPath $packs -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^$($revit.Runtime)\.\d+\.\d+$" } | Sort-Object { [version]$_.Name } -Descending)
        if (!$pack.Count) { throw "Missing offline .NET $($revit.Runtime) reference pack. Install the matching x64 .NET SDK, then retry." }
        $refs = Join-Path $pack[0].FullName "ref/net$($revit.Runtime).0"
        $references += @(Get-ChildItem -LiteralPath $refs -Filter '*.dll' -File | Select-Object -ExpandProperty FullName)
    }
    $compilerArgs += '/langversion:5'
    foreach ($reference in $references) {
        if (!(Test-Path -LiteralPath $reference)) { throw "Required reference is missing: $reference" }
        $compilerArgs += '/reference:"'+$reference+'"'
    }
    $compilerArgs += @($sources | ForEach-Object { '"'+$_.FullName+'"' })
    $response = Join-Path $out 'compile.rsp'
    [IO.File]::WriteAllLines($response, [string[]]$compilerArgs, (New-Object Text.UTF8Encoding($true)))
    Write-Output "Compiling against installed Revit $v API (.NET $($revit.Runtime)). No downloads."
    if ($v -eq '2024') { & $compiler "@$response" | Write-Output }
    else { & $dotnet.Source $compiler "@$response" | Write-Output }
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $dll)) { throw "Compilation failed for Revit $v (exit $LASTEXITCODE)." }
    if ([Reflection.AssemblyName]::GetAssemblyName($dll).Name -ne 'TCAutoOrient') { throw 'Compiled assembly identity is incorrect.' }
    Write-Output "Built: $dll"
}
