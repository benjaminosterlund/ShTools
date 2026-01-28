[CmdletBinding()]
param(
    [string]$Path = '.'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\Tooling.Core\Tooling.Core.psd1') -Force

Invoke-Sync -Path $Path