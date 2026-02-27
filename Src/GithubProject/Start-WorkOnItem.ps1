<#
.SYNOPSIS
  Start working on a task by moving it to "In Progress".
.DESCRIPTION
  Proper kanban workflow script to start work on ready tasks. Finds items in Todo 
  status (ready to be worked on), assigns them to current user, and moves to In Progress.
  Follows the workflow: Todo → Assign → In Progress
.PARAMETER Title
  Search for items by title (partial match, case insensitive)
.PARAMETER IssueNumber
  Start work on a specific GitHub issue by number
.PARAMETER Interactive
  Show interactive selection from available items
.EXAMPLE
  .\Start-WorkOnItem.ps1 -Title "API"
  # Find items with "API" in title and move to In Progress
.EXAMPLE
  .\Start-WorkOnItem.ps1 -IssueNumber 1
  # Start work on issue #1
.EXAMPLE
  .\Start-WorkOnItem.ps1 -Interactive
  # Browse available items and select one to start
#>

[CmdletBinding()]
param(
    [string]$Title,
    [int]$IssueNumber,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
# Set console output encoding to handle Unicode characters properly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Import module and check configuration
& (Join-Path $PSScriptRoot '..\Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot

if (-not (Test-GhProjectConfig)) { exit 1 }

Write-Host "`n=== Start Working On Item ===" -ForegroundColor Cyan
Write-Host "Project: $($Config.GhRepo) (Project $($Config.GhProjectNumber))`n" -ForegroundColor Gray

# No helper functions needed - using module functions

try {
    $selectedItem = $null
    
    # Get items that can be started (Todo status - ready to be picked up)
    $startableStatuses = @("Todo")
    
    # Find items based on criteria
    if ($IssueNumber) {
        # Search by issue number
        $items = Find-ProjectItems -IssueNumber $IssueNumber
        if ($items.Count -eq 0) {
            Write-Host "❌ Issue #$IssueNumber not found in project." -ForegroundColor Red
            exit 1
        }
        
        $item = $items[0]
        if ($item.Status -notin $startableStatuses) {
            Write-Host "⚠️  Issue #$IssueNumber is currently in '$($item.Status)' status." -ForegroundColor Yellow
            Write-Host "Only items in 'Todo' status (ready to be worked on) can be started with this script." -ForegroundColor Gray
            Write-Host "Use .\Move-KanbanItem.ps1 for other status changes." -ForegroundColor Gray
            exit 0
        }
        
        $selectedItem = $item
        Write-Host "Found issue: $($selectedItem.DisplayName) [$($selectedItem.Status)]" -ForegroundColor Green
        
    } elseif ($Title) {
        # Search by title and filter for startable items
        $allItems = Find-ProjectItems -Title $Title
        $items = $allItems | Where-Object { $_.Status -in $startableStatuses }
        
        if ($allItems.Count -gt 0 -and $items.Count -eq 0) {
            Write-Host "Found items matching '$Title', but none are available to start:" -ForegroundColor Yellow
            foreach ($item in $allItems) {
                Write-Host "  - $($item.DisplayName) [$($item.Status)]" -ForegroundColor Gray
            }
            Write-Host "`nOnly items in 'Todo' status (ready to be worked on) can be started with this script." -ForegroundColor Gray
            Write-Host "Use .\Move-KanbanItem.ps1 for other status changes." -ForegroundColor Gray
            exit 0
        }
        
        if ($items.Count -eq 0) {
            Write-Host "❌ No startable items found matching title '$Title'." -ForegroundColor Red
            exit 1
        }
        
        if ($items.Count -eq 1) {
            $selectedItem = $items[0]
            Write-Host "Found item: $($selectedItem.DisplayName) [$($selectedItem.Status)]" -ForegroundColor Green
        } else {
            Write-Host "Found multiple startable items matching '$Title':" -ForegroundColor Yellow
            $selectedItem = Select-ProjectItem -Items $items -Title "Select item to start working on"
            if (-not $selectedItem) {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
        
    } elseif ($Interactive) {
        # Interactive mode - show all startable items
        $allItems = Find-ProjectItems -Limit 100
        $items = $allItems | Where-Object { $_.Status -in $startableStatuses }
        
        if ($items.Count -eq 0) {
            Write-Host "No items available to start work on." -ForegroundColor Yellow
            Write-Host "Try creating new items with .\Add-KanbanItem.ps1" -ForegroundColor Gray
            exit 0
        }
        
        $selectedItem = Select-ProjectItem -Items $items -Title "Select item to start working on"
        if (-not $selectedItem) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
        
    } else {
        # No parameters provided - default to showing Todo items for selection
        Write-Host "No search criteria provided. Showing items ready to start (Todo status)..." -ForegroundColor Yellow
        
        $allItems = Find-ProjectItems -Status "Todo" -Limit 100
        if ($allItems.Count -eq 0) {
            Write-Host "❌ No items in 'Todo' status found." -ForegroundColor Red
            Write-Host "Try creating new items with .\Add-KanbanItem.ps1" -ForegroundColor Gray
            Write-Host "`nOr use search options:" -ForegroundColor Gray
            Write-Host "  -Title 'text'     # Search by title" -ForegroundColor Gray
            Write-Host "  -IssueNumber 1    # Start work on specific issue" -ForegroundColor Gray
            Write-Host "  -Interactive      # Browse all available items" -ForegroundColor Gray
            exit 1
        }
        
        Write-Host "Found $($allItems.Count) item$(if($allItems.Count -ne 1){'s'}) ready to start:" -ForegroundColor Green
        $selectedItem = Select-ProjectItem -Items $allItems -Title "Select item to start working on"
        if (-not $selectedItem) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Start work process: Assign + Move to In Progress
    Write-Host "`n--- Starting Work ---" -ForegroundColor Green
    Write-Host "Item: $($selectedItem.DisplayName)" -ForegroundColor White
    Write-Host "Status: $($selectedItem.Status) → In Progress" -ForegroundColor Gray
    
    # Step 1: Assign issue (if it's an issue, not a draft)
    $assignmentResult = $null
    if ($selectedItem.Type -eq "Issue" -and $selectedItem.IssueNumber) {
        Write-Host "Assigning issue to current user..." -ForegroundColor Yellow
        $assignmentResult = Set-IssueAssignment -IssueNumber $selectedItem.IssueNumber
        
        if ($assignmentResult -and $assignmentResult.Success) {
            Write-Host "✅ Assigned to: $($assignmentResult.Assignee)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Assignment failed, but continuing with status change..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️  Draft item - skipping assignment" -ForegroundColor Gray
    }
    
    # Step 2: Move to In Progress
    Write-Host "Moving to In Progress..." -ForegroundColor Yellow
    $result = Set-ProjectItemStatus -ItemId $selectedItem.ProjectItemId -StatusKey "InProgress"
    
    Write-Host "✅ Started working on item!" -ForegroundColor Green
    Write-Host "   $($selectedItem.DisplayName)" -ForegroundColor White
    Write-Host "   Status: $($selectedItem.Status) → $($result.StatusName)" -ForegroundColor Gray
    if ($assignmentResult -and $assignmentResult.Success) {
        Write-Host "   Assigned to: $($assignmentResult.Assignee)" -ForegroundColor Gray
    }
    
    Write-Host "`n💡 Tips:" -ForegroundColor Cyan
    Write-Host "  • Use .\Show-Kanban.ps1 to see the updated board" -ForegroundColor Gray
    Write-Host "  • Use .\Move-KanbanItem.ps1 to move to other statuses" -ForegroundColor Gray

} catch {
    Write-Host "❌ Error starting work: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Done ---`n" -ForegroundColor Cyan