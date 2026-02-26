<#
.SYNOPSIS
    Git helper functions for repository management.
.DESCRIPTION
    Provides reusable functions for git operations including testing,
    status checking, initialization, and display functions.
#>

function Test-GitRepository {
    <#
    .SYNOPSIS
        Check if directory is a git repository.
    .DESCRIPTION
        Tests whether a given directory is a valid git repository
        by checking for the presence of the .git directory.
    .PARAMETER Directory
        Directory path to test
    .EXAMPLE
        Test-GitRepository -Directory "C:\MyProject"
        Returns $true if it's a git repo, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )
    
    $gitPath = Join-Path $Directory ".git"
    return (Test-Path $gitPath)
}

function Get-GitStatus {
    <#
    .SYNOPSIS
        Get current git repository status.
    .DESCRIPTION
        Retrieves the current branch, remote URL, and uncommitted changes
        from a git repository.
    .PARAMETER Directory
        Directory path of the git repository
    .EXAMPLE
        $status = Get-GitStatus -Directory "C:\MyProject"
        $status.Branch    # Current branch name
        $status.RemoteUrl # Remote origin URL
        $status.HasChanges # Whether there are uncommitted changes
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )
    
    try {
        Push-Location $Directory
        $status = git status --porcelain
        $branch = git rev-parse --abbrev-ref HEAD
        $remoteUrl = git config --get remote.origin.url
        
        return @{
            Branch = $branch
            HasChanges = ($null -ne $status -and $status.Count -gt 0)
            RemoteUrl = $remoteUrl
            StatusOutput = $status
        }
    }
    catch {
        Write-Warning "Error getting git status: $_"
        return $null
    }
    finally {
        Pop-Location
    }
}

function Show-GitStatus {
    <#
    .SYNOPSIS
        Display git repository status to the user.
    .DESCRIPTION
        Formats and displays git repository information including
        branch, remote, and uncommitted changes in a user-friendly way.
    .PARAMETER Status
        Hashtable containing git status information (from Get-GitStatus)
    .PARAMETER Directory
        Directory path of the git repository
    .EXAMPLE
        $status = Get-GitStatus -Directory "C:\MyProject"
        Show-GitStatus -Status $status -Directory "C:\MyProject"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Status,
        
        [Parameter(Mandatory)]
        [string]$Directory
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Git Repository Status" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "  📁 Repository Path: " -NoNewline -ForegroundColor White
    Write-Host $Directory -ForegroundColor Gray
    
    Write-Host "  🌿 Branch: " -NoNewline -ForegroundColor White
    Write-Host $Status.Branch -ForegroundColor Green
    
    Write-Host "  🔗 Remote: " -NoNewline -ForegroundColor White
    if ($Status.RemoteUrl) {
        Write-Host $Status.RemoteUrl -ForegroundColor Green
    }
    else {
        Write-Host "(not configured)" -ForegroundColor Yellow
    }
    
    Write-Host "  📝 Changes: " -NoNewline -ForegroundColor White
    if ($Status.HasChanges) {
        Write-Host "Yes" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Modified files:" -ForegroundColor Gray
        $Status.StatusOutput | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "None (working directory clean)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Initialize-GitRepository {
    <#
    .SYNOPSIS
        Initialize a new git repository.
    .DESCRIPTION
        Creates a new git repository in the specified directory.
        Configures user name and email, creates a .gitignore file,
        and makes an initial commit if there are files to commit.
    .PARAMETER Directory
        Directory path where git will be initialized
    .PARAMETER UserName
        Git user name for commits
    .PARAMETER UserEmail
        Git user email for commits
    .EXAMPLE
        Initialize-GitRepository -Directory "C:\MyProject" -UserName "John Doe" -UserEmail "john@example.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,
        
        [Parameter(Mandatory)]
        [string]$UserName,
        
        [Parameter(Mandatory)]
        [string]$UserEmail
    )
    
    Write-Host ""
    Write-Host "🔧 Initializing Git repository..." -ForegroundColor Cyan
    
    try {
        Push-Location $Directory
        
        # Initialize repository
        git init
        Write-Host "✅ Git repository initialized" -ForegroundColor Green
        
        # Set user config
        git config user.name $UserName
        Write-Host "✅ Git user name set: $UserName" -ForegroundColor Green
        
        git config user.email $UserEmail
        Write-Host "✅ Git user email set: $UserEmail" -ForegroundColor Green
        
        # Check for .gitignore
        $gitignorePath = Join-Path $Directory ".gitignore"
        if (-not (Test-Path $gitignorePath)) {
            # Create basic .gitignore
            $gitignoreContent = @"
# Build results
bin/
obj/
*.dll
*.exe

# Visual Studio
.vs/
*.user
*.suo

# PowerShell
.vscode/

# Environment
.env
user_secrets.json

# Node modules
node_modules/

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
"@
            Set-Content -Path $gitignorePath -Value $gitignoreContent -Encoding UTF8
            Write-Host "✅ .gitignore file created" -ForegroundColor Green
        }
        
        # Stage and commit initial setup files if any exist
        git add .
        $status = git status --porcelain
        
        if ($null -ne $status -and $status.Count -gt 0) {
            git commit -m "Initial commit: project setup"
            Write-Host "✅ Initial commit created" -ForegroundColor Green
        }
        
    }
    catch {
        Write-Host "❌ Error initializing git: $_" -ForegroundColor Red
        throw
    }
    finally {
        Pop-Location
    }
}
