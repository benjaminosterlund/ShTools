
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,
    [Parameter(Mandatory=$false)]
    [string[]]$TestProjectPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\ShTools.Core\ShTools.Core.psd1') -Force

# Select project paths
$ProjectPath = Select-DotnetProject -ProjectPath:$ProjectPath
$TestProjectPath = Select-DotnetProjects -ProjectPath:$TestProjectPath

& InitUserSecrets.ps1 -ProjectPath:$ProjectPath -TestProjectPath:$TestProjectPath
& SetDbConnectionString.ps1 -ProjectPath:$ProjectPath