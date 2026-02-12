<#
.SYNOPSIS
  Initialize GitHub Project automation configuration.
.DESCRIPTION
  Sets up the ghproject.config.json file with project information and caches
  field metadata to improve performance of automation scripts.
  Will not overwrite existing configuration unless -Force is specified.
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

# Interactive mode if parameters not provided
if (-not $Owner) {
    Write-Host "`nTo set up automation, I need some information about your GitHub project:" -ForegroundColor Yellow
    $Owner = Read-Host "GitHub repository owner/organization"
    if (-not $Owner.Trim()) {
        Write-Host "Owner cannot be empty!" -ForegroundColor Red
        exit 1
    }
}

if (-not $Repo) {
    $Repo = Read-Host "Repository name (without owner prefix)"
    if (-not $Repo.Trim()) {
        Write-Host "Repository name cannot be empty!" -ForegroundColor Red
        exit 1
    }
}

if (-not $ProjectNumber) {
    Write-Host "`nYou can find the project number in the project URL:" -ForegroundColor Gray
    Write-Host "https://github.com/users/$Owner/projects/[PROJECT_NUMBER]" -ForegroundColor Gray
    do {
        $projectInput = Read-Host "GitHub Project number"
        if ($projectInput -and $projectInput -match '^\d+$') {
            $ProjectNumber = [int]$projectInput
        } else {
            Write-Host "Please enter a valid project number." -ForegroundColor Red
        }
    } while (-not $ProjectNumber)
}

Write-Host "`n📋 Configuration Summary:" -ForegroundColor Yellow
Write-Host "Owner: $Owner" -ForegroundColor White
Write-Host "Repository: $Repo" -ForegroundColor White  
Write-Host "Project Number: $ProjectNumber" -ForegroundColor White
Write-Host "Full Repository: $Owner/$Repo" -ForegroundColor White

$confirm = Read-Host "`nProceed with initialization? (y/N)"
if ($confirm -notlike "y*") {
    Write-Host "Initialization cancelled." -ForegroundColor Yellow
    exit 0
}

try {
    # Run the initialization
    if ($Force) {
        Initialize-GhProject -Owner $Owner -Repo $Repo -ProjectNumber $ProjectNumber -Force | Out-Null
    } else {
        Initialize-GhProject -Owner $Owner -Repo $Repo -ProjectNumber $ProjectNumber | Out-Null
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