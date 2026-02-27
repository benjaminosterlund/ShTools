#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize and configure Git repository for the project.
.DESCRIPTION
    Checks if the current directory is a Git repository.
    If not, offers to initialize Git.
    Configures Git user name and email.
.PARAMETER RootDirectory
    Root directory for the project (defaults to current directory)
.PARAMETER UserName
    Git user name (optional, will prompt if not provided)
.PARAMETER UserEmail
    Git user email (optional, will prompt if not provided)
.PARAMETER Force
    Force re-initialization of Git repository
.EXAMPLE
    .\InitGit.ps1
    
    Checks if current directory is a git repo and initializes if needed.
.EXAMPLE
    .\InitGit.ps1 -RootDirectory "C:\MyProject" -UserName "John Doe" -UserEmail "john@example.com"
    
    Initialize git for specific directory with credentials.
#>

[CmdletBinding()]
param(
    [string]$RootDirectory = "..\..\",
    [string]$UserName,
    [string]$UserEmail,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Import ShTools module if not already loaded
& (Join-Path $PSScriptRoot '..\Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot


# Main execution
function Start-GitInitialization {
    param(
        [string]$RootDirectory,
        [string]$UserName,
        [string]$UserEmail,
        [switch]$Force
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Git Repository Initialization Tool                ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if already a git repository
    $isGitRepo = Test-GitRepository -Directory $RootDirectory
    
    if ($isGitRepo -and -not $Force) {
        Write-Host "✅ Git repository already initialized" -ForegroundColor Green
        
        # Show current status
        $gitStatus = Get-GitStatus -Directory $RootDirectory
        if ($gitStatus) {
            Show-GitStatus -Status $gitStatus -Directory $RootDirectory
        }
        
        # Ask if user wants to reconfigure
        if (Select-YesNo -Title "Reconfigure git settings?" -DefaultYes $false) {
            $UserName = if (-not $UserName) { Read-Host "Enter Git user name" } else { $UserName }
            $UserEmail = if (-not $UserEmail) { Read-Host "Enter Git user email" } else { $UserEmail }
            
            try {
                Push-Location $RootDirectory
                
                if ($UserName) {
                    git config user.name $UserName
                    Write-Host "✅ Git user name updated: $UserName" -ForegroundColor Green
                }
                
                if ($UserEmail) {
                    git config user.email $UserEmail
                    Write-Host "✅ Git user email updated: $UserEmail" -ForegroundColor Green
                }
            }
            finally {
                Pop-Location
            }
        }
        
        return
    }
    
    if ($isGitRepo -and $Force) {
        Write-Host "⚠️  Force re-initialization requested" -ForegroundColor Yellow
        if (-not (Select-YesNo -Title "This will reinitialize git. Continue?" -DefaultYes $false)) {
            Write-Host "Re-initialization cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    # Not a git repo - offer to initialize
    if (-not $isGitRepo) {
        Write-Host "⚠️  Not a git repository" -ForegroundColor Yellow
        Write-Host ""
        
        if (-not (Select-YesNo -Title "Initialize git repository?" -DefaultYes $true)) {
            Write-Host "Git initialization skipped." -ForegroundColor Yellow
            return
        }
        
        # Get user credentials if not provided
        if (-not $UserName) {
            $UserName = Read-Host "Enter your Git user name"
        }
        
        if (-not $UserEmail) {
            $UserEmail = Read-Host "Enter your Git user email"
        }
        
        if (-not $UserName -or -not $UserEmail) {
            Write-Host "Git user name and email are required." -ForegroundColor Red
            return
        }
    }
    
    # Initialize repository
    Initialize-GitRepository -Directory $RootDirectory -UserName $UserName -UserEmail $UserEmail
    
    # Show final status
    Write-Host ""
    $gitStatus = Get-GitStatus -Directory $RootDirectory
    if ($gitStatus) {
        Show-GitStatus -Status $gitStatus -Directory $RootDirectory
    }
    
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║            Git initialization complete!                      ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# Execute main function
Start-GitInitialization -RootDirectory $RootDirectory -UserName $UserName -UserEmail $UserEmail -Force:$Force
