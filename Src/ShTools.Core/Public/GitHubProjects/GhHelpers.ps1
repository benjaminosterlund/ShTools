

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


function Get-GhProjects{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo
    )
    return gh project list --owner $Owner --repo $Repo --format json | ConvertFrom-Json
}

function Invoke-GhProjectCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Title,
        [string]$Body
    )
    $cmd = @("project", "create", "--owner", $Owner, "--repo", $Repo, "--title", $Title, "--format", "json")
    if ($Body) { $cmd += @("--body", $Body) }
    return gh @cmd | ConvertFrom-Json
}


function Invoke-GhProjectLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo
    )

    gh project link $ProjectNumber --owner $Owner --repo $Repo | Out-Null
}

function Invoke-GhProjectFieldCreate { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet("SINGLE_SELECT","TEXT")][string]$DataType,
        [string[]]$SingleSelectOptions
    )

    $cmd = @("project", "field-create", $ProjectNumber, "--owner", $Owner, "--name", $Name, "--data-type", $DataType, "--format", "json")

    if ($DataType -eq "SINGLE_SELECT" -and $SingleSelectOptions) {
        $cmd += @("--single-select-options", ($SingleSelectOptions -join ","))
    }

    gh @cmd | ConvertFrom-Json
}


function Test-GhProjectExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ProjectNumber,
        [Parameter(Mandatory)][string]$Owner
    )

    try {
        # If it exists, view returns 0 and prints json
        gh project view $ProjectNumber --owner $Owner --format json | Out-Null
        return $true
    }
    catch {
        return $false
    }
}