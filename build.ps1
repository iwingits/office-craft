# Build OfficeCraft.exe from src/host.cs with the four-colour icon embedded.
# Adjust paths below if your checkout is not at C:\Users\iwin\office-craft.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$csc  = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$sma  = Get-ChildItem "$env:SystemRoot\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation" -Recurse -Filter System.Management.Automation.dll | Select-Object -First 1 -ExpandProperty FullName
$ico  = Join-Path $root 'assets\OfficeCraft.ico'
$src  = Join-Path $root 'src\host.cs'
$out  = Join-Path $root 'OfficeCraft.exe'

if(-not (Test-Path $ico)){ powershell -ExecutionPolicy Bypass -File (Join-Path $root 'src\make-icon.ps1') }
& $csc /nologo /target:winexe /platform:anycpu "/win32icon:$ico" "/reference:$sma" "/out:$out" $src
Write-Host "Built: $out"
