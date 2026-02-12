#requires -Version 7.0
<#
.SYNOPSIS
  PowerShell module for automating GitHub Project and Issue workflows.
.DESCRIPTION
  Loads configuration from ghproject.config.json and provides helper functions
  for working with GitHub CLI (gh) to manage issues and project board items.
#>

# --- Module Dependencies ----------------------------------------------------

function Import-PSMenuIfAvailable {
    <#
    .SYNOPSIS
        Import PSMenu module if available, install if needed with user consent.
    .DESCRIPTION
        Checks for PSMenu module and imports it for better interactive menus.
        If not found, offers to install it from PowerShell Gallery.
    #>
    try {
        if (Get-Module -Name PSMenu -ListAvailable -ErrorAction SilentlyContinue) {
            Import-Module PSMenu -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Host "📋 PSMenu module not found. This provides better interactive menus." -ForegroundColor Yellow
            $install = Read-Host "Install PSMenu from PowerShell Gallery? (y/N)"
            if ($install -eq 'y' -or $install -eq 'Y') {
                Write-Host "Installing PSMenu..." -ForegroundColor Cyan
                Install-Module -Name PSMenu -Scope CurrentUser -Force
                Import-Module PSMenu -Force
                Write-Host "✅ PSMenu installed and imported!" -ForegroundColor Green
                return $true
            } else {
                Write-Host "PSMenu not installed. Will use basic console menus." -ForegroundColor Gray
                return $false
            }
        }
    } catch {
        Write-Warning "Failed to import PSMenu: $($_.Exception.Message). Using basic menus."
        return $false
    }
}

# --- GitHub CLI Wrapper Functions -------------------------------------------

function Invoke-GhProjectView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner
    )
    return gh project view $ProjectNumber --owner $Owner --format json | ConvertFrom-Json
}

function Invoke-GhProjectFieldList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner
    )
    return gh project field-list $ProjectNumber --owner $Owner --format json | ConvertFrom-Json
}

function Invoke-GhProjectItemList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner,
        [int]$Limit = 100
    )
    return gh project item-list $ProjectNumber --owner $Owner --format json --limit $Limit | ConvertFrom-Json
}

function Invoke-GhIssueCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Title,
        [string]$Body,
        [string[]]$Labels
    )
    $cmd = @("issue", "create", "--repo", $Repo, "--title", $Title)
    if ($Body) { $cmd += @("--body", $Body) }
    if ($Labels) { $cmd += @("--label", ($Labels -join ",")) }
    
    # gh issue create returns the URL, we need to parse it to get issue details
    $issueUrl = gh @cmd
    if ($issueUrl -and $issueUrl -match '/issues/(\d+)$') {
        $issueNumber = [int]$Matches[1]
        # Get the issue details using gh issue view
        return gh issue view $issueNumber --repo $Repo --json number,title,body,url,state,labels | ConvertFrom-Json
    } else {
        throw "Failed to create issue or parse issue URL: $issueUrl"
    }
}

function Invoke-GhProjectItemCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Title,
        [string]$Body
    )
    $cmd = @("project", "item-create", $ProjectNumber, "--owner", $Owner, "--title", $Title, "--format", "json")
    if ($Body) { $cmd += @("--body", $Body) }
    return gh @cmd | ConvertFrom-Json
}

function Invoke-GhProjectItemAdd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$IssueUrl
    )
    return gh project item-add $ProjectNumber --owner $Owner --url $IssueUrl --format json | ConvertFrom-Json
}

function Invoke-GhProjectItemEdit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ItemId,
        [Parameter(Mandatory)][string]$ProjectId,
        [Parameter(Mandatory)][string]$FieldId,
        [Parameter(Mandatory)][string]$OptionId
    )
    return gh project item-edit --id $ItemId --project-id $ProjectId --field-id $FieldId --single-select-option-id $OptionId 2>&1
}

function Invoke-GhApiUser {
    [CmdletBinding()]
    param()
    return gh api user --jq .login 2>$null
}

function Invoke-GhIssueEdit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$IssueNumber,
        [Parameter(Mandatory)][string]$Repo,
        [string]$AddAssignee,
        [string]$RemoveAssignee
    )
    $cmd = @("issue", "edit", $IssueNumber, "--repo", $Repo)
    if ($AddAssignee) { $cmd += @("--add-assignee", $AddAssignee) }
    if ($RemoveAssignee) { $cmd += @("--remove-assignee", $RemoveAssignee) }
    gh @cmd | Out-Null
}

function Invoke-GhIssueView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$IssueNumber,
        [Parameter(Mandatory)][string]$Repo
    )
    return gh issue view $IssueNumber --repo $Repo --json assignees --jq '.assignees | map(.login) | join(", ")' 2>$null
}

# --- Load configuration ------------------------------------------------------

# Look for config in project root (two levels up from scripts/automation)
$ConfigPath = Join-Path $PSScriptRoot '..\..\ghproject.config.json'
if (Test-Path $ConfigPath) {
    $Script:Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $Script:GhOwner         = $Script:Config.GhOwner
    $Script:GhProjectNumber = $Script:Config.GhProjectNumber
    $Script:GhRepo          = $Script:Config.GhRepo

    Write-Verbose "Loaded config for $($Script:Config.GhRepo) (Project $($Script:Config.GhProjectNumber))"
    if ($Script:Config._Cache.StatusOptions) {
        $statusCount = $Script:Config._Cache.StatusOptions.PSObject.Properties.Count
        Write-Verbose "Status options loaded: $statusCount entries"
    }
} else {
    # Config will be checked by Test-GhProjectConfig when scripts call it
    $Script:Config = $null
}

# --- Functions ---------------------------------------------------------------

function Test-GhProjectConfig {
    <#
    .SYNOPSIS
        Check if GitHub Project configuration exists and show helpful error if not.
    .DESCRIPTION
        Tests for ghproject.config.json in project root and displays a user-friendly
        error message with setup instructions if the file is missing.
    .PARAMETER ConfigPath
        Optional path to config file (defaults to project root)
    .EXAMPLE
        Test-GhProjectConfig
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )
    
    if (-not $ConfigPath) {
        # Default to project root (two levels up from scripts/automation)
        $ConfigPath = Join-Path $PSScriptRoot '..\..\..\..\ghproject.config.json'
    }
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Host ""
        Write-Host "❌ GitHub Project automation not initialized!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Configuration file missing: " -NoNewline -ForegroundColor Yellow
        Write-Host "ghproject.config.json" -ForegroundColor White
        Write-Host ""
        Write-Host "🔧 To set up automation:" -ForegroundColor Cyan
        Write-Host "   .\Initialize-Project.ps1" -ForegroundColor Green
        Write-Host ""
        Write-Host "💡 Or run with your project details:" -ForegroundColor Gray
        Write-Host "   .\Initialize-Project.ps1 -Owner <owner> -Repo <repo> -ProjectNumber <num>" -ForegroundColor Gray
        Write-Host ""
        return $false
    }
    
    return $true
}

function Initialize-GhProject {
    <#
    .SYNOPSIS
        Initialize GitHub Project configuration and cache field metadata.
    .DESCRIPTION
        Creates ghproject.config.json file with project information and caches
        field metadata (including status options with IDs) to reduce API calls.
        Will not overwrite existing config unless -Force is specified.
    .PARAMETER Owner
        GitHub repository owner/organization name
    .PARAMETER Repo
        GitHub repository name (without owner prefix)
    .PARAMETER ProjectNumber
        GitHub Project number (visible in project URL)
    .PARAMETER ConfigPath
        Path where to create the config file (defaults to project root)
    .PARAMETER Force
        Overwrite existing configuration file
    .EXAMPLE
        Initialize-GhProject -Owner "myorg" -Repo "myrepo" -ProjectNumber 1
    .EXAMPLE
        Initialize-GhProject -Owner "myorg" -Repo "myrepo" -ProjectNumber 1 -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][int]$ProjectNumber,
        [string]$ConfigPath,
        [switch]$Force
    )
    
    if (-not $ConfigPath) {
        # Default to project root (two levels up from scripts/automation)
        $ConfigPath = Join-Path $PSScriptRoot '..\..\..\..\ghproject.config.json'
    }
    
    # Check if config already exists
    if (Test-Path $ConfigPath) {
        if (-not $Force) {
            Write-Host "✅ Configuration already exists: $ConfigPath" -ForegroundColor Green
            Write-Host "Use -Force to overwrite existing configuration." -ForegroundColor Yellow
            
            # Show current config info
            try {
                $existingConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                Write-Host "`nCurrent configuration:" -ForegroundColor Cyan
                Write-Host "  Owner: $($existingConfig.GhOwner)" -ForegroundColor Gray
                Write-Host "  Repo: $($existingConfig.GhRepo)" -ForegroundColor Gray
                Write-Host "  Project: $($existingConfig.GhProjectNumber)" -ForegroundColor Gray
                if ($existingConfig._Cache.LastUpdated) {
                    Write-Host "  Cache Updated: $($existingConfig._Cache.LastUpdated)" -ForegroundColor Gray
                }
            } catch {
                Write-Host "  (Could not read existing config details)" -ForegroundColor Red
            }
            
            return $existingConfig
        } else {
            Write-Host "⚠️  Overwriting existing configuration..." -ForegroundColor Yellow
        }
    }
    
    Write-Host "🔧 Initializing GitHub Project configuration..." -ForegroundColor Cyan
    Write-Host "Owner: $Owner" -ForegroundColor Gray
    Write-Host "Repo: $Repo" -ForegroundColor Gray
    Write-Host "Project Number: $ProjectNumber" -ForegroundColor Gray
    Write-Host "Config Path: $ConfigPath" -ForegroundColor Gray
    
    try {
        # Test GitHub CLI access and get project info
        Write-Host "`n📡 Fetching project information..." -ForegroundColor Yellow
        $projectInfo = Invoke-GhProjectView -ProjectNumber $ProjectNumber -Owner $Owner
        $projectId = $projectInfo.id
        $projectTitle = $projectInfo.title
        
        Write-Host "✅ Found project: '$projectTitle' (ID: $projectId)" -ForegroundColor Green
        
        # Fetch and cache field information
        Write-Host "`n📋 Fetching field definitions..." -ForegroundColor Yellow
        $fields = Invoke-GhProjectFieldList -ProjectNumber $ProjectNumber -Owner $Owner
        
        # Extract Status field and build enhanced mapping
        $statusField = $fields.fields | Where-Object { $_.name -eq "Status" }
        if (-not $statusField) {
            throw "No 'Status' field found in project. Available fields: $($fields.fields.name -join ', ')"
        }
        
        Write-Host "✅ Found Status field with $($statusField.options.Count) options" -ForegroundColor Green
        
        # Build status options with both friendly keys and GitHub names/IDs
        # Preserve API order (which matches board column order)
        $statusOptionsCache = @{}
        $statusOrder = @()
        
        foreach ($option in $statusField.options) {
            # Create friendly key for PowerShell usage (remove spaces, make PascalCase)
            $friendlyKey = switch ($option.name) {
                "Backlog" { "Backlog" }
                "Todo" { "Todo" }
                "In progress" { "InProgress" }
                "In review" { "InReview" }  
                "Done" { "Done" }
                default { 
                    # Handle custom status names by removing spaces and special chars
                    $option.name -replace '[^a-zA-Z0-9]', ''
                }
            }
            
            $statusOptionsCache[$friendlyKey] = @{
                id = $option.id
                name = $option.name
                key = $friendlyKey
                order = $statusOrder.Count  # Preserve API order
            }
            $statusOrder += $friendlyKey
            Write-Host "  $friendlyKey -> '$($option.name)' (ID: $($option.id))" -ForegroundColor Gray
        }
        
        Write-Host "✅ Status order (left to right): $($statusOrder -join ' → ')" -ForegroundColor Green
        
        # Create comprehensive config
        $config = @{
            GhOwner = $Owner
            GhProjectNumber = $ProjectNumber
            GhRepo = "$Owner/$Repo"
            # Cache for efficiency
            _Cache = @{
                ProjectId = $projectId
                ProjectTitle = $projectTitle
                StatusField = @{
                    Id = $statusField.id
                    Name = $statusField.name
                    Type = $statusField.type
                }
                StatusOptions = $statusOptionsCache
                LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        # Save configuration
        Write-Host "`n💾 Saving configuration..." -ForegroundColor Yellow
        $config | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
        
        Write-Host "✅ Configuration saved to: $ConfigPath" -ForegroundColor Green
        Write-Host "`n🎉 GitHub Project initialization complete!" -ForegroundColor Cyan
        Write-Host "You can now use:" -ForegroundColor White
        Write-Host "  .\Add-KanbanItem.ps1 - Create issues and draft items" -ForegroundColor Gray
        Write-Host "  .\Show-Kanban.ps1 - Display your kanban board" -ForegroundColor Gray
        
        return $config
        
    } catch {
        Write-Host "❌ Initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-GhProjectField {
    [CmdletBinding()]
    param([string]$FieldName = "Status")
    $fields = Invoke-GhProjectFieldList -ProjectNumber $Script:GhProjectNumber -Owner $Script:GhOwner
    $f = $fields.fields | Where-Object { $_.name -eq $FieldName }
    if (-not $f) { throw "Field '$FieldName' not found. Available: $($fields.fields.name -join ', ')" }
    return $f
}

function Get-GhProjectItemIdByIssue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$IssueNumber)
    $items = Invoke-GhProjectItemList -ProjectNumber $Script:GhProjectNumber -Owner $Script:GhOwner
    $match = $items.items | Where-Object {
        $_.contentType -eq "Issue" -and $_.content.number -eq $IssueNumber
    }
    if ($match) { return $match.id }
    return $null
}

function New-RepoIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Body,
        [string[]]$Labels
    )
    # Always provide body (required for non-interactive mode)
    $bodyText = if ($Body) { $Body } else { "Issue created via automation script." }
    
    $issue = Invoke-GhIssueCreate -Repo $Script:GhRepo -Title $Title -Body $bodyText -Labels $Labels
    
    return [PSCustomObject]@{
        Number = $issue.number
        Url    = $issue.url
        Title  = $issue.title
    }
}

function Add-ProjectItemForIssue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$IssueNumber)
    $url = "https://github.com/$Script:GhRepo/issues/$IssueNumber"
    $item = Invoke-GhProjectItemAdd -ProjectNumber $Script:GhProjectNumber -Owner $Script:GhOwner -IssueUrl $url
    return $item.id
}

function New-ProjectDraftItem {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Title, [string]$Body)
    $item = Invoke-GhProjectItemCreate -ProjectNumber $Script:GhProjectNumber -Owner $Script:GhOwner -Title $Title -Body $Body
    return $item.id
}

function Set-ProjectItemStatus {
    <#
    .SYNOPSIS
        Set the status of a project item.
    .DESCRIPTION
        Updates the status field of a GitHub project item using the cached field metadata.
    .PARAMETER ItemId
        The project item ID (not the issue number)
    .PARAMETER StatusKey
        The status key (friendly name like 'Backlog', 'Todo', etc.)
    .EXAMPLE
        Set-ProjectItemStatus -ItemId "PVTI_lAHOAx1E6c4BGQlEzggbFWI" -StatusKey "InProgress"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [Parameter(Mandatory)]
        [string]$StatusKey
    )
    
    if (-not $Script:Config) {
        throw "Configuration not loaded. Run Test-GhProjectConfig first."
    }
    
    # Get status option details from cache
    if (-not $Script:Config._Cache.StatusOptions.$StatusKey) {
        $availableKeys = $Script:Config._Cache.StatusOptions.PSObject.Properties.Name -join ', '
        throw "Invalid status key '$StatusKey'. Available options: $availableKeys"
    }
    
    $statusOption = $Script:Config._Cache.StatusOptions.$StatusKey
    $statusFieldId = $Script:Config._Cache.StatusField.Id
    $projectId = $Script:Config._Cache.ProjectId
    
    # Update the project item status using GitHub CLI
    $result = Invoke-GhProjectItemEdit -ItemId $ItemId -ProjectId $projectId -FieldId $statusFieldId -OptionId $statusOption.id
    
    # Check if the command failed
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update project item status. Error: $result"
    }
    
    return @{
        ItemId = $ItemId
        StatusKey = $StatusKey
        StatusName = $statusOption.name
        Success = $true
    }
}

function New-TaskFromIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Body,
        [string[]]$Labels,
        [ValidateSet("Backlog","Todo","InProgress","InReview","Done")] [string]$StatusKey = "Backlog"
    )
    $issue = New-RepoIssue -Title $Title -Body $Body -Labels $Labels
    $itemId = Add-ProjectItemForIssue -IssueNumber $issue.Number
    if ($itemId) { Set-ProjectItemStatus -ItemId $itemId -StatusKey $StatusKey }
    [PSCustomObject]@{ Issue = $issue; ProjectItemId = $itemId }
}

function New-DraftTasks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Titles,
        [ValidateSet("Backlog","Todo","InProgress","InReview","Done")] [string]$StatusKey = "Backlog"
    )
    foreach ($t in $Titles) {
        $itemId = New-ProjectDraftItem -Title $t
        if ($itemId) {
            Set-ProjectItemStatus -ItemId $itemId -StatusKey $StatusKey
            Write-Host "Draft: $t  ->  $($Script:GhStatusMap[$StatusKey])"
        }
    }
}

function Find-ProjectItems {
    <#
    .SYNOPSIS
        Find project items by title, issue number, or status.
    .DESCRIPTION
        Searches project items with flexible filtering options. Returns items with
        both project item ID and display information.
    .PARAMETER Title
        Search by title (partial match, case insensitive)
    .PARAMETER IssueNumber
        Search by GitHub issue number
    .PARAMETER Status
        Filter by current status (exact match)
    .PARAMETER Limit
        Maximum number of items to search through (default: 100)
    .EXAMPLE
        Find-ProjectItems -Title "API"
    .EXAMPLE
        Find-ProjectItems -IssueNumber 1
    .EXAMPLE
        Find-ProjectItems -Status "Todo"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string]$Title,
        [int]$IssueNumber,
        [string]$Status,
        [int]$Limit = 100
    )
    
    try {
        if (-not $Script:Config) {
            throw "Configuration not loaded. Run Test-GhProjectConfig first."
        }

        # Fetch all project items
        try {
            $items = Invoke-GhProjectItemList -ProjectNumber $Script:Config.GhProjectNumber -Owner $Script:Config.GhOwner -Limit $Limit
        }
        catch {
            Write-Warning "Failed to fetch project items: $($_.Exception.Message)"
            return ,[PSCustomObject[]]@()
        }
        
        if (-not $items.items) {
            return ,[PSCustomObject[]]@()
        }

        [System.Collections.ArrayList]$results = @()
        
        foreach ($item in $items.items) {
            $match = $true
            
            # Filter by title (partial, case insensitive)
            if ($Title -and $item.title -notlike "*$Title*") {
                $match = $false
            }
            
            # Filter by issue number
            if ($IssueNumber -and ($item.content.type -ne "Issue" -or $item.content.number -ne $IssueNumber)) {
                $match = $false
            }
            
            # Filter by status
            if ($Status -and $item.status -ne $Status) {
                $match = $false
            }

            if ($match) {
                [void]$results.Add([PSCustomObject]@{
                    ProjectItemId = $item.id
                    Title = $item.title
                    Status = $item.status
                    Type = $item.content.type
                    IssueNumber = if ($item.content.type -eq "Issue") { $item.content.number } else { $null }
                    Url = if ($item.content.type -eq "Issue") { $item.content.url } else { $null }
                    DisplayName = if ($item.content.type -eq "Issue") { "#$($item.content.number) $($item.title)" } else { $item.title }
                })
            }
        }
        
        # Always return an array, even if empty - force array using comma operator
        return ,[PSCustomObject[]]$results.ToArray()
    }
    catch {
        # Always return empty array on any error
        Write-Warning "Error in Find-ProjectItems: $($_.Exception.Message)"
        return ,[PSCustomObject[]]@()
    }
}function Set-IssueAssignment {
    <#
    .SYNOPSIS
        Assign a GitHub issue to the current user.
    .DESCRIPTION
        Assigns a GitHub issue to the currently authenticated user. Only works
        for issues, not draft items.
    .PARAMETER IssueNumber
        GitHub issue number to assign
    .EXAMPLE
        Set-IssueAssignment -IssueNumber 1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$IssueNumber
    )
    
    if (-not $Script:Config) {
        throw "Configuration not loaded. Run Test-GhProjectConfig first."
    }
    
    try {
        # Get current user
        $currentUser = Invoke-GhApiUser
        if (-not $currentUser) {
            Write-Warning "Could not get current user. Issue will not be assigned."
            return $false
        }
        
        # Assign the issue
        Invoke-GhIssueEdit -IssueNumber $IssueNumber -Repo $Script:Config.GhRepo -AddAssignee $currentUser
        
        return @{
            IssueNumber = $IssueNumber
            Assignee = $currentUser
            Success = $true
        }
    } catch {
        Write-Warning "Failed to assign issue #$IssueNumber`: $($_.Exception.Message)"
        return $false
    }
}

function Select-ProjectItem {
    <#
    .SYNOPSIS
        Interactive selection of project items using PSMenu if available.
    .DESCRIPTION
        Shows a menu of project items for user selection. Uses PSMenu for better
        UI if available, falls back to basic console menu.
    .PARAMETER Items
        Array of project items to choose from
    .PARAMETER Title
        Menu title (default: "Select Project Item")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [string]$Title = "Select Project Item"
    )
    
    if ($Items.Count -eq 0) {
        Write-Host "No items available for selection." -ForegroundColor Yellow
        return $null
    }
    
    # Try to use PSMenu if available
    $usePSMenu = Import-PSMenuIfAvailable
    
    if ($usePSMenu) {
        # Use PSMenu for better interactive experience
        try {
            Write-Host $Title -ForegroundColor Yellow
            $menuOptions = @()
            foreach ($item in $Items) {
                $menuOptions += "$($item.DisplayName) [$($item.Status)]"
            }
            
            $selectedIndex = Show-Menu $menuOptions
            Write-Verbose "PSMenu returned: '$selectedIndex' (Type: $($selectedIndex.GetType().Name))"
            
            # Handle different return value possibilities from PSMenu
            if ($selectedIndex -is [int] -and $selectedIndex -gt 0 -and $selectedIndex -le $Items.Count) {
                # 1-based index, convert to 0-based
                return $Items[$selectedIndex - 1]
            } elseif ($selectedIndex -is [int] -and $selectedIndex -ge 0 -and $selectedIndex -lt $Items.Count) {
                # 0-based index
                return $Items[$selectedIndex]
            } elseif ($selectedIndex -is [string] -and $menuOptions -contains $selectedIndex) {
                # Returned the actual string value
                $index = $menuOptions.IndexOf($selectedIndex)
                return $Items[$index]
            } else {
                Write-Verbose "PSMenu selection cancelled or invalid: $selectedIndex"
                return $null  # User cancelled (ESC or invalid selection)
            }
        } catch {
            Write-Warning "PSMenu failed: $($_.Exception.Message). Using basic menu."
            # Fall through to basic menu
        }
    }
    
    # Basic console menu (fallback or when PSMenu not available)
    Write-Host $Title -ForegroundColor Yellow
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        Write-Host "  [$($i + 1)] $($item.DisplayName) [$($item.Status)]" -ForegroundColor White
    }
    
    do {
        $selection = Read-Host "`nSelect item [1-$($Items.Count), 0=cancel]"
        if ($selection -eq "0") { return $null }
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $Items.Count) {
            return $Items[[int]$selection - 1]
        }
        Write-Host "Invalid selection. Please enter a number between 0 and $($Items.Count)." -ForegroundColor Red
    } while ($true)
}

function Select-ItemType {
    <#
    .SYNOPSIS
        Interactive selection of item type (Issue or Draft) using PSMenu if available.
    .DESCRIPTION
        Shows a menu for selecting between Issue and Draft item types. Uses PSMenu
        for better UI if available, falls back to basic console menu.
    .PARAMETER Title
        Menu title (default: "Choose the type of item to create")
    .RETURNS
        String: "Issue" or "Draft", or $null if cancelled
    #>
    [CmdletBinding()]
    param(
        [string]$Title = "Choose the type of item to create"
    )
    
    # Try to use PSMenu if available
    $usePSMenu = Import-PSMenuIfAvailable
    
    if ($usePSMenu) {
        try {
            Write-Host $Title -ForegroundColor Yellow
            $menuOptions = @(
                "Issue (tracked in GitHub Issues with number, assignees, etc.)",
                "Draft/Backlog Item (simple task item in project only)"
            )
            
            $selectedIndex = Show-Menu $menuOptions
            Write-Verbose "PSMenu returned: '$selectedIndex' (Type: $($selectedIndex.GetType().Name))"
            
            # Handle different return value possibilities from PSMenu
            if ($selectedIndex -is [int] -and $selectedIndex -gt 0 -and $selectedIndex -le 2) {
                # 1-based index
                return @("Issue", "Draft")[$selectedIndex - 1]
            } elseif ($selectedIndex -is [int] -and $selectedIndex -ge 0 -and $selectedIndex -lt 2) {
                # 0-based index
                return @("Issue", "Draft")[$selectedIndex]
            } elseif ($selectedIndex -is [string] -and $menuOptions -contains $selectedIndex) {
                # Returned the actual string value
                $index = $menuOptions.IndexOf($selectedIndex)
                return @("Issue", "Draft")[$index]
            } else {
                Write-Verbose "PSMenu selection cancelled or invalid: $selectedIndex"
                return $null  # User cancelled (ESC or invalid selection)
            }
        } catch {
            Write-Warning "PSMenu failed: $($_.Exception.Message). Using basic menu."
            # Fall through to basic menu
        }
    }
    
    # Basic console menu (fallback or when PSMenu not available)
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "1. Issue (tracked in GitHub Issues with number, assignees, etc.)" -ForegroundColor White
    Write-Host "2. Draft/Backlog Item (simple task item in project only)" -ForegroundColor White
    
    do {
        $selection = Read-Host "`nEnter choice [1-2, 0=cancel]"
        switch ($selection) {
            "1" { return "Issue" }
            "2" { return "Draft" }
            "0" { return $null }
            default { Write-Host "Invalid choice. Please enter 1, 2, or 0 to cancel." -ForegroundColor Red }
        }
    } while ($true)
}

function Select-StatusOption {
    <#
    .SYNOPSIS
        Interactive selection of status options using PSMenu if available.
    .DESCRIPTION
        Shows a menu of available status options for user selection. Uses PSMenu
        for better UI if available, falls back to basic console menu.
    .PARAMETER CurrentStatus
        Current status to highlight (optional)
    .PARAMETER Title
        Menu title (default: "Select Status")
    #>
    [CmdletBinding()]
    param(
        [string]$CurrentStatus,
        [string]$Title = "Select Status"
    )
    
    if (-not $Script:Config._Cache.StatusOptions) {
        throw "Status options not loaded in configuration"
    }
    
    # Get status options in board order
    $statusEntries = $Script:Config._Cache.StatusOptions.PSObject.Properties | Sort-Object { $_.Value.order }
    
    # Try to use PSMenu if available
    $usePSMenu = Import-PSMenuIfAvailable
    
    if ($usePSMenu) {
        # Use PSMenu for better interactive experience
        try {
            Write-Host $Title -ForegroundColor Yellow
            $menuOptions = @()
            foreach ($entry in $statusEntries) {
                $statusKey = $entry.Name
                $statusInfo = $entry.Value
                $marker = if ($statusInfo.name -eq $CurrentStatus) { " (current)" } else { "" }
                $menuOptions += "$statusKey -> '$($statusInfo.name)'$marker"
            }
            
            $selectedIndex = Show-Menu $menuOptions
            Write-Verbose "PSMenu returned: '$selectedIndex' (Type: $($selectedIndex.GetType().Name))"
            
            # Handle different return value possibilities from PSMenu
            if ($selectedIndex -is [int] -and $selectedIndex -gt 0 -and $selectedIndex -le $statusEntries.Count) {
                # 1-based index, convert to 0-based
                return $statusEntries[$selectedIndex - 1].Name
            } elseif ($selectedIndex -is [int] -and $selectedIndex -ge 0 -and $selectedIndex -lt $statusEntries.Count) {
                # 0-based index
                return $statusEntries[$selectedIndex].Name
            } elseif ($selectedIndex -is [string] -and $menuOptions -contains $selectedIndex) {
                # Returned the actual string value
                $index = $menuOptions.IndexOf($selectedIndex)
                return $statusEntries[$index].Name
            } else {
                Write-Verbose "PSMenu selection cancelled or invalid: $selectedIndex"
                return $null  # User cancelled (ESC or invalid selection)
            }
        } catch {
            Write-Warning "PSMenu failed: $($_.Exception.Message). Using basic menu."
            # Fall through to basic menu
        }
    }
    
    # Basic console menu (fallback or when PSMenu not available)
    Write-Host $Title -ForegroundColor Yellow
    for ($i = 0; $i -lt $statusEntries.Count; $i++) {
        $entry = $statusEntries[$i]
        $statusKey = $entry.Name
        $statusInfo = $entry.Value
        $marker = if ($statusInfo.name -eq $CurrentStatus) { " (current)" } else { "" }
        Write-Host "  [$($i + 1)] $statusKey -> '$($statusInfo.name)'$marker" -ForegroundColor White
    }
    
    do {
        $selection = Read-Host "`nSelect target status [1-$($statusEntries.Count), 0=cancel]"
        if ($selection -eq "0") { return $null }
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $statusEntries.Count) {
            return $statusEntries[[int]$selection - 1].Name
        }
        Write-Host "Invalid selection. Please enter a number between 0 and $($statusEntries.Count)." -ForegroundColor Red
    } while ($true)
}

function Show-ProjectKanban {
    <#
    .SYNOPSIS
        Display the GitHub Project kanban board in the terminal.
    .DESCRIPTION
        Fetches and displays all project items grouped by status with clean formatting.
        Handles Unicode characters and shows issues vs draft items differently.
    .PARAMETER Limit
        Maximum number of items to fetch (default: 100)
    .EXAMPLE
        Show-ProjectKanban
    .EXAMPLE
        Show-ProjectKanban -Limit 50
    #>
    [CmdletBinding()]
    param(
        [int]$Limit = 100
    )
    
    if (-not $Script:Config) {
        throw "Configuration not loaded. Run Test-GhProjectConfig first."
    }
    
    Write-Host "`n=== GitHub Project Kanban for $($Script:Config.GhRepo) (Project $($Script:Config.GhProjectNumber)) ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Fetch all project items
    $items = Invoke-GhProjectItemList -ProjectNumber $Script:Config.GhProjectNumber -Owner $Script:Config.GhOwner -Limit $Limit
    if (-not $items.items) {
        Write-Host "No items found." -ForegroundColor Yellow
        return
    }
    
    # Group by Status
    $groups = $items.items | Group-Object { $_.status }
    
    # Preserve defined order using GitHub display names in board order
    $statusOrder = $Script:Config._Cache.StatusOptions.PSObject.Properties | 
                   Sort-Object { $_.Value.order } | 
                   ForEach-Object { $_.Value.name }
    
    foreach ($status in $statusOrder) {
        $group = $groups | Where-Object { $_.Name -eq $status }
        if ($group) {
            Write-Host "## $status" -ForegroundColor Green
            foreach ($item in $group.Group) {
                # Clean up Unicode characters that may not display properly
                $title = $item.title -replace [char]0x201C, '"' -replace [char]0x201D, '"' -replace [char]0x2018, "'" -replace [char]0x2019, "'"
                if ($item.content.type -eq "Issue") {
                    $num = $item.content.number
                    $url = $item.content.url
                    
                    # Get assignee information for GitHub issues
                    try {
                        $assigneeInfo = Invoke-GhIssueView -IssueNumber $num -Repo $Script:Config.GhRepo
                        $assigneeDisplay = if ($assigneeInfo -and $assigneeInfo.Trim() -ne "") { 
                            " [@$assigneeInfo]" 
                        } else { 
                            " [unassigned]" 
                        }
                    } catch {
                        $assigneeDisplay = " [unassigned]"
                    }
                    
                    Write-Host " - #$num $title$assigneeDisplay" -ForegroundColor White
                    Write-Host "   $url" -ForegroundColor DarkGray
                } else {
                    Write-Host " - $title" -ForegroundColor White
                }
            }
            Write-Host ""
        }
    }
    
    Write-Host "End of board view." -ForegroundColor Cyan
    Write-Host ""
}

function New-ProjectItem {
    <#
    .SYNOPSIS
        Create a new GitHub issue or draft item and add it to the project kanban.
    .DESCRIPTION
        Creates either a GitHub Issue (with full issue tracking) or a draft item
        (simple kanban-only task) and sets its status on the project board.
    .PARAMETER Title
        Title for the new item
    .PARAMETER Body
        Description/body for the item (optional for drafts, recommended for issues)
    .PARAMETER Type
        Type of item: 'Issue' or 'Draft'
    .PARAMETER Status
        Initial status for the item
    .PARAMETER Labels
        Labels to add (only applies to Issues)
    .EXAMPLE
        New-ProjectItem -Title "Fix bug" -Type Issue -Status Todo
    .EXAMPLE
        New-ProjectItem -Title "Research task" -Type Draft -Status Backlog
    .EXAMPLE
        New-ProjectItem -Title "New feature" -Body "Add user authentication" -Type Issue -Status Todo -Labels @("enhancement", "priority-high")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Body,
        [Parameter(Mandatory)][ValidateSet("Issue","Draft")][string]$Type,
        [ValidateSet("Backlog","Todo","InProgress","InReview","Done")][string]$Status = "Backlog",
        [string[]]$Labels
    )
    
    if (-not $Script:Config) {
        throw "Configuration not loaded. Run Test-GhProjectConfig first."
    }
    
    # Clean up title to handle any Unicode characters
    $Title = $Title -replace [char]0x201C, '"' -replace [char]0x201D, '"' -replace [char]0x2018, "'" -replace [char]0x2019, "'"
    
    try {
        if ($Type -eq "Issue") {
            Write-Verbose "Creating GitHub issue..."
            $result = New-TaskFromIssue -Title $Title -Body $Body -Labels $Labels -StatusKey $Status
            
            [PSCustomObject]@{
                Type = "Issue"
                Issue = $result.Issue
                ProjectItemId = $result.ProjectItemId
                Status = $Status
                StatusMapped = $Script:Config.GhStatusMap.PSObject.Properties | Where-Object Name -eq $Status | Select-Object -ExpandProperty Value
            }
            
        } else {
            Write-Verbose "Creating draft backlog item..."
            $itemId = New-ProjectDraftItem -Title $Title -Body $Body
            if ($itemId) {
                Set-ProjectItemStatus -ItemId $itemId -StatusKey $Status
                
                [PSCustomObject]@{
                    Type = "Draft"
                    Title = $Title
                    ProjectItemId = $itemId
                    Status = $Status
                    StatusMapped = $Script:Config.GhStatusMap.PSObject.Properties | Where-Object Name -eq $Status | Select-Object -ExpandProperty Value
                }
            } else {
                throw "Failed to create draft item."
            }
        }
        
    } catch {
        throw "Error creating $Type`: $($_.Exception.Message)"
    }
}

# Export-ModuleMember -Function * -Variable Config
