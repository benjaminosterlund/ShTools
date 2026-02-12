<#
.SYNOPSIS
  Move items between kanban board columns.
.DESCRIPTION
  Find and move GitHub Project items to different status columns. Supports
  searching by title, issue number, or selecting from a list.
.PARAMETER Title
  Search for items by title (partial match, case insensitive)
.PARAMETER IssueNumber
  Move a specific GitHub issue by number
.PARAMETER ItemId
  Move a specific item by its Project Item ID
.PARAMETER ToStatus
  Target status to move the item(s) to
.PARAMETER Interactive
  Show interactive selection when multiple items match
.EXAMPLE
  .\Move-KanbanItem.ps1 -Title "API" -ToStatus InProgress
  # Find items with "API" in title and move to In Progress
.EXAMPLE
  .\Move-KanbanItem.ps1 -IssueNumber 1 -ToStatus Done
  # Move issue #1 to Done
.EXAMPLE
  .\Move-KanbanItem.ps1 -Interactive
  # Interactive mode - browse and select items to move
#>

[CmdletBinding()]
param(
    [string]$Title,
    [int]$IssueNumber,
    [string]$ItemId,
    [string]$ToStatus,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
# Set console output encoding to handle Unicode characters properly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Import module and check configuration
Import-Module (Join-Path $PSScriptRoot '..\ShTools.Core\ShTools.Core.psd1') -Force

if (-not (Test-GhProjectConfig)) { exit 1 }

Write-Host "`n=== Move Kanban Items ===" -ForegroundColor Cyan
Write-Host "Project: $($Config.GhRepo) (Project $($Config.GhProjectNumber))`n" -ForegroundColor Gray

# No helper functions needed - using module functions

try {
    $selectedItem = $null
    $targetStatus = $ToStatus

    # Find items based on provided criteria
    if ($ItemId) {
        # Direct item ID provided - we'll need to validate it exists
        $allItems = Find-ProjectItems -Limit 100
        $selectedItem = $allItems | Where-Object { $_.ProjectItemId -eq $ItemId }
        if (-not $selectedItem) {
            Write-Host "❌ Item with ID '$ItemId' not found." -ForegroundColor Red
            exit 1
        }
        Write-Host "Found item: $($selectedItem.DisplayName) [$($selectedItem.Status)]" -ForegroundColor Green
    } elseif ($IssueNumber) {
        # Search by issue number
        $items = Find-ProjectItems -IssueNumber $IssueNumber
        if ($items.Count -eq 0) {
            Write-Host "❌ Issue #$IssueNumber not found in project." -ForegroundColor Red
            exit 1
        }
        $selectedItem = $items[0]
        Write-Host "Found issue: $($selectedItem.DisplayName) [$($selectedItem.Status)]" -ForegroundColor Green
    } elseif ($Title) {
        # Search by title
        $items = Find-ProjectItems -Title $Title
        if ($items.Count -eq 0) {
            Write-Host "❌ No items found matching title '$Title'." -ForegroundColor Red
            exit 1
        }
        
        if ($items.Count -eq 1) {
            $selectedItem = $items[0]
            Write-Host "Found item: $($selectedItem.DisplayName) [$($selectedItem.Status)]" -ForegroundColor Green
        } else {
            Write-Host "Found multiple items matching '$Title':" -ForegroundColor Yellow
            $selectedItem = Select-ProjectItem -Items $items -Title "Select item to move"
            if (-not $selectedItem) {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    } elseif ($Interactive) {
        # Interactive mode - show all items
        $items = Find-ProjectItems -Limit 100
        if ($items.Count -eq 0) {
            Write-Host "❌ No items found in project." -ForegroundColor Red
            exit 1
        }
        
        $selectedItem = Select-ProjectItem -Items $items -Title "Select item to move"
        if (-not $selectedItem) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    } elseif (-not $Title -and -not $IssueNumber -and -not $ItemId) {
        # No parameters provided - enter full interactive mode
        Write-Host "🎯 Interactive Mode: Select item and target status" -ForegroundColor Cyan
        
        $items = Find-ProjectItems -Limit 100
        if ($items.Count -eq 0) {
            Write-Host "❌ No items found in project." -ForegroundColor Red
            exit 1
        }
        
        $selectedItem = Select-ProjectItem -Items $items -Title "Select item to move"
        if (-not $selectedItem) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "❌ Please provide search criteria:" -ForegroundColor Red
        Write-Host "  -Title 'text'     # Search by title" -ForegroundColor Gray
        Write-Host "  -IssueNumber 1    # Move specific issue" -ForegroundColor Gray
        Write-Host "  -ItemId 'ID'      # Move by project item ID" -ForegroundColor Gray
        Write-Host "  -Interactive      # Browse all items" -ForegroundColor Gray
        exit 1
    }

    # Get target status if not provided
    if (-not $targetStatus) {
        $targetStatus = Select-StatusOption -CurrentStatus $selectedItem.Status -Title "Select target status for '$($selectedItem.DisplayName)'"
        if (-not $targetStatus) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Validate target status exists
    if (-not $Config._Cache.StatusOptions.$targetStatus) {
        $availableStatuses = ($Config._Cache.StatusOptions.PSObject.Properties.Name -join ', ')
        Write-Host "❌ Invalid status '$targetStatus'. Available options: $availableStatuses" -ForegroundColor Red
        exit 1
    }
    
    # Check if already in target status
    $targetStatusInfo = $Config._Cache.StatusOptions.$targetStatus
    if ($selectedItem.Status -eq $targetStatusInfo.name) {
        Write-Host "⚠️  Item is already in status '$($targetStatusInfo.name)'." -ForegroundColor Yellow
        exit 0
    }

    # Move the item
    Write-Host "`n--- Moving Item ---" -ForegroundColor Green
    Write-Host "Item: $($selectedItem.DisplayName)" -ForegroundColor White
    Write-Host "From: $($selectedItem.Status)" -ForegroundColor Gray
    Write-Host "To: $targetStatus -> '$($targetStatusInfo.name)'" -ForegroundColor Gray

    $result = Set-ProjectItemStatus -ItemId $selectedItem.ProjectItemId -StatusKey $targetStatus
    
    Write-Host "✅ Successfully moved item!" -ForegroundColor Green
    Write-Host "   $($selectedItem.DisplayName)" -ForegroundColor White
    Write-Host "   Status: $($selectedItem.Status) → $($result.StatusName)" -ForegroundColor Gray
    
    Write-Host "`n💡 Use .\Show-Kanban.ps1 to see the updated board!" -ForegroundColor Cyan

} catch {
    Write-Host "❌ Error moving item: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Done ---`n" -ForegroundColor Cyan