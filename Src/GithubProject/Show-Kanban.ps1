<#
.SYNOPSIS
  Display GitHub Project Kanban board in the terminal.
.DESCRIPTION
  Simple wrapper script that displays the project kanban board using the
  Show-ProjectKanban function from the ghproject module.
.PARAMETER Limit
  Maximum number of items to fetch (default: 100)
.EXAMPLE
  .\Show-Kanban.ps1
.EXAMPLE
  .\Show-Kanban.ps1 -Limit 50
#>

[CmdletBinding()]
param(
    [int]$Limit = 100
)

$ErrorActionPreference = 'Stop'
# Set console output encoding to handle Unicode characters properly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Import module and check configuration
Import-Module (Join-Path $PSScriptRoot '..\ShTools.Core\ShTools.Core.psd1') -Force

if (-not (Test-GhProjectConfig)) { exit 1 }

# Display the kanban board
Show-ProjectKanban -Limit $Limit
