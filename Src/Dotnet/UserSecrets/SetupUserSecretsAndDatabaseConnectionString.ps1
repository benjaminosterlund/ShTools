
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,
    [Parameter(Mandatory=$false)]
    [string[]]$TestProjectPath
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '..\..\Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot

# Select project paths
$ProjectPath = Select-DotnetProject -ProjectPath:$ProjectPath
$TestProjectPath = Select-DotnetProjects -ProjectPath:$TestProjectPath

& InitUserSecrets.ps1 -ProjectPath:$ProjectPath -TestProjectPath:$TestProjectPath
& SetDbConnectionString.ps1 -ProjectPath:$ProjectPath