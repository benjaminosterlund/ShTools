<#
.SYNOPSIS
  Initialize GitHub Project automation configuration.
.DESCRIPTION
  Sets up the config file with project information and caches
  field metadata to improve performance of automation scripts.
.PARAMETER Owner
  GitHub repository owner/organization name
.PARAMETER Repo
  Repository name (without owner prefix)
.PARAMETER ProjectNumber
  GitHub Project number (visible in project URL)
.PARAMETER Force
  Overwrite existing configuration file
.EXAMPLE
  .\Initialize-Project.ps1
  # Interactive mode - prompts for all inputs
.EXAMPLE
  .\Initialize-Project.ps1 -Owner "myorg" -Repo "myrepo" -ProjectNumber 1
  # Direct initialization with parameters
.EXAMPLE
  .\Initialize-Project.ps1 -Force
  # Recreate configuration (interactive mode with overwrite)
#>

[CmdletBinding()]
param(
    [string]$Owner,
    [string]$Repo, 
    [int]$ProjectNumber,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
# Set console output encoding to handle Unicode characters properly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Import-Module (Join-Path $PSScriptRoot '..\ShTools.Core\ShTools.Core.psd1') -Force


Write-Host "`n🚀 GitHub Project Automation Setup" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan


# Load existing config if available
$ConfigPath = Join-Path $PSScriptRoot '..\..\shtools.config.json'
$config = Get-ShToolsConfig -ConfigPath $ConfigPath -ErrorAction SilentlyContinue


#Ensure GitHub section exists in config
$resolvedGitHub = Update-GitHubSection -ConfigPath $ConfigPath -CurrentConfig $config -Owner $Owner -Repo $Repo -ProjectNumber $ProjectNumber
$Owner = $resolvedGitHub.Owner
$Repo = $resolvedGitHub.Repo
$ProjectNumber = [int]$resolvedGitHub.ProjectNumber


$confirm = Read-Host "`nProceed with initialization? (y/N)"
if ($confirm -notlike "y*") {
    Write-Host "Initialization cancelled." -ForegroundColor Yellow
    exit 0
}

try {
    # Run the initialization, which will setup cache field metadata
    if ($Force) {
    Initialize-GhProject -Owner $Owner -Repo $Repo -ProjectNumber $ProjectNumber -ConfigPath $ConfigPath -Force -RefreshCache | Out-Null
    } else {
    Initialize-GhProject -Owner $Owner -Repo $Repo -ProjectNumber $ProjectNumber -ConfigPath $ConfigPath -RefreshCache | Out-Null
    }
    
    Write-Host "`n✨ Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Create items: .\Add-KanbanItem.ps1" -ForegroundColor White
    Write-Host "2. View board: .\Show-Kanban.ps1" -ForegroundColor White
    Write-Host "3. Move items: .\Move-KanbanItem.ps1 (coming soon)" -ForegroundColor Gray
    
} catch {
    Write-Host "`n❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Make sure you're authenticated: gh auth status" -ForegroundColor Gray
    Write-Host "2. Verify project access: gh project view $ProjectNumber --owner $Owner" -ForegroundColor Gray
    Write-Host "3. Check project scope: gh auth refresh -s project" -ForegroundColor Gray
    exit 1
}