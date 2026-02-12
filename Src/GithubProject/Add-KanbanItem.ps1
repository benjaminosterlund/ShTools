<#
.SYNOPSIS
  Add new issues or draft items to the GitHub Project Kanban board.
.DESCRIPTION
  Creates GitHub issues or draft kanban items and adds them to the project board.
  Supports both interactive mode and direct parameter usage.
.PARAMETER Title
  The title for the new item
.PARAMETER Body
  The description/body for the new item (optional)
.PARAMETER Type
  The type of item to create: 'Issue' or 'Draft'
.PARAMETER Status
  The initial status for the item (defaults to leftmost column in project board)
.PARAMETER Labels
  Labels to add (only applies to Issues)
.PARAMETER Interactive
  Force interactive mode even when parameters are provided
.EXAMPLE
  .\Add-KanbanItem.ps1
  # Interactive mode - prompts for all inputs
.EXAMPLE
  .\Add-KanbanItem.ps1 -Title "Fix bug" -Type Issue -Status Todo
  # Create an issue directly with specified parameters
.EXAMPLE
  .\Add-KanbanItem.ps1 -Title "Research" -Type Draft -Status Backlog
  # Create a draft item directly
#>

[CmdletBinding()]
param(
    [string]$Title,
    [string]$Body,
    [ValidateSet("Issue","Draft")][string]$Type,
    [string]$Status,  # Will be validated against actual project statuses
    [string[]]$Labels,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
# Set console output encoding to handle Unicode characters properly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Import module and check configuration
Import-Module (Join-Path $PSScriptRoot '..\ShTools.Core\ShTools.Core.psd1') -Force


if (-not (Test-GhProjectConfig)) { exit 1 }

Write-Host "`n=== Add Item to GitHub Project Kanban ===" -ForegroundColor Cyan
Write-Host "Project: $($Config.GhRepo) (Project $($Config.GhProjectNumber))`n" -ForegroundColor Gray

# Interactive mode if parameters not provided or explicitly requested
if ($Interactive -or -not $Title -or -not $Type) {
    
    if (-not $Type) {
        $Type = Select-ItemType
        if (-not $Type) {
            Write-Host "Selection cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    if (-not $Title) {
        $Title = Read-Host "`nEnter the title"
        if (-not $Title.Trim()) {
            Write-Host "Title cannot be empty!" -ForegroundColor Red
            exit 1
        }
    }
    
    if (-not $Body) {
        $Body = Read-Host "Enter description/body (optional, press Enter to skip)"
    }
    
    if ($Type -eq "Issue" -and -not $Labels) {
        $labelsInput = Read-Host "Enter labels (comma-separated, optional)"
        if ($labelsInput.Trim()) {
            $Labels = $labelsInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
    }
    
    # Status selection (interactive mode)
    if (-not $Status) {
        $Status = Select-StatusOption -Title "Choose initial status"
        if (-not $Status) {
            # Use leftmost column as default if no selection made
            $statusEntries = $Config._Cache.StatusOptions.PSObject.Properties | Sort-Object { $_.Value.order }
            $Status = $statusEntries[0].Name
            Write-Host "No status selected, using default: $Status" -ForegroundColor Gray
        }
    }
}

# If Status still not set (non-interactive mode), use leftmost column as default
if (-not $Status) {
    $firstStatus = $Config._Cache.StatusOptions.PSObject.Properties | Sort-Object { $_.Value.order } | Select-Object -First 1
    $Status = $firstStatus.Name
    Write-Host "Using default status (leftmost column): $Status ($($firstStatus.Value.name))" -ForegroundColor Gray
}

# Validate the status exists in the project
if (-not $Config._Cache.StatusOptions.$Status) {
    $availableStatuses = ($Config._Cache.StatusOptions.PSObject.Properties.Name -join ', ')
    Write-Host "❌ Invalid status '$Status'. Available options: $availableStatuses" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Creating $Type ---" -ForegroundColor Green
Write-Host "Title: $Title" -ForegroundColor White
if ($Body) { Write-Host "Body: $($Body.Substring(0, [Math]::Min(100, $Body.Length)))$(if($Body.Length -gt 100){'...'})" -ForegroundColor Gray }
if ($Labels) { Write-Host "Labels: $($Labels -join ', ')" -ForegroundColor Gray }
$statusInfo = $Config._Cache.StatusOptions.$Status
Write-Host "Status: $Status -> '$($statusInfo.name)'" -ForegroundColor White

try {
    Write-Host "`nCreating $Type..." -ForegroundColor Yellow
    $result = New-ProjectItem -Title $Title -Body $Body -Type $Type -Status $Status -Labels $Labels
    
    Write-Host "✅ Successfully created $($result.Type.ToLower())!" -ForegroundColor Green
    if ($result.Type -eq "Issue") {
        Write-Host "   Issue #$($result.Issue.Number): $($result.Issue.Title)" -ForegroundColor White
        Write-Host "   URL: $($result.Issue.Url)" -ForegroundColor Gray
    } else {
        Write-Host "   Title: $($result.Title)" -ForegroundColor White
        Write-Host "   Status: $($result.StatusMapped)" -ForegroundColor Gray
    }
    Write-Host "   Project Item ID: $($result.ProjectItemId)" -ForegroundColor Gray
    
    Write-Host "`n💡 Use .\Show-Kanban.ps1 to see the updated board!" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Error creating item: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Done ---`n" -ForegroundColor Cyan