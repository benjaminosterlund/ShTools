#Requires -Version 7.0

<#
.SYNOPSIS
    Interactive setup wizard for ShTools components with multi-select menu.
.DESCRIPTION
    Provides a multi-select menu to choose which ShTools components to initialize.
    Runs the corresponding initialization scripts for selected components.
    Displays current configuration status before setup.
.PARAMETER RootDirectory
    Root directory for the project (defaults to current directory)
.EXAMPLE
    .\Setup.ps1
    
    Runs the interactive setup wizard, showing current status and available components.
.EXAMPLE
    .\Setup.ps1 -RootDirectory "C:\MyProject"
    
    Runs setup for a specific project directory.
#>

[CmdletBinding()]
param(
    [string]$RootDirectory = $PWD
)

$ErrorActionPreference = 'Stop'

# ===== MODULE INITIALIZATION =====
if (-not (Get-Module ShTools.Core)) {
    $modulePath = Join-Path $PSScriptRoot "ShTools.Core\ShTools.Core.psd1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}
Import-PSMenuIfAvailable -ErrorAction SilentlyContinue | Out-Null

# ===== SETUP OPTIONS =====
# Single source of truth for all setup components
$script:SetupOptions = [ordered]@{
    "Git Repository Setup" = @{
        Description = "Initialize or configure Git repository and user credentials"
        Script = "Git\InitGit.ps1"
    }
    "GitHub Project Setup" = @{
        Description = "Initialize GitHub Project configuration and kanban board"
        Script = "GithubProject\InitGithubProject.ps1"
    }
    ".NET Project Settings" = @{
        Description = "Configure .NET project paths and settings"
        Script = "Dotnet\InitDotnet.ps1"
    }
    ".NET User Secrets" = @{
        Description = "Setup user secrets for .NET projects"
        Script = "Dotnet\UserSecrets\InitUserSecrets.ps1"
    }
    "Database Connection Strings" = @{
        Description = "Setup user secrets and database connection strings"
        Script = "Dotnet\UserSecrets\SetupUserSecretsAndDatabaseConnectionString.ps1"
    }
    "LocalDb Settings" = @{
        Description = "Configure LocalDb project settings"
        Script = "LocalDb\InitLocalDb.ps1"
    }
}

# ===== MENU DISPLAY =====


function Show-SetupMenu {
    <#
    .SYNOPSIS
        Display multi-select menu for choosing setup components.
    #>
    [CmdletBinding()]
    param()
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          ShTools Interactive Setup Wizard                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📋 Select components to initialize (use Space to select, Enter to confirm):" -ForegroundColor Yellow
    Write-Host ""
    
    $menuItems = $script:SetupOptions.Keys | ForEach-Object {
        "$_ - $($script:SetupOptions[$_].Description)"
    }
    
    $selections = Show-Menu -MenuItems $menuItems -MultiSelect
    
    if (-not $selections -or $selections.Count -eq 0) {
        Write-Host "No components selected. Exiting." -ForegroundColor Yellow
        return @()
    }
    
    return $selections | ForEach-Object { $_ -replace ' - .*$', '' }
}

# ===== COMPONENT EXECUTION =====
function Invoke-SetupComponent {
    <#
    .SYNOPSIS
        Execute setup for a specific component by calling its Init script.
    #>
    [CmdletBinding()]
    param(
        [string]$ComponentName,
        [hashtable]$ComponentInfo,
        [string]$RootDirectory
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Setting up: $ComponentName" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # All components now have scripts - just call them
    $scriptPath = Join-Path $PSScriptRoot $ComponentInfo.Script
    
    if (Test-Path $scriptPath) {
        try {
            & $scriptPath -RootDirectory $RootDirectory
        }
        catch {
            throw "Failed to execute $scriptPath : $_"
        }
    } else {
        Write-Warning "Init script not found: $scriptPath"
        Write-Host "Expected: $scriptPath" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "✅ Completed: $ComponentName" -ForegroundColor Green
}

# ===== MAIN ORCHESTRATION =====
function Start-InteractiveSetup {
    [CmdletBinding()]
    param([string]$RootDirectory)
    
    Write-Host ""
    Write-Host "Analyzing current setup..." -ForegroundColor Cyan
    $configStatus = Get-ConfigurationStatus -RootDirectory $RootDirectory
    Show-ConfigurationStatus -Status $configStatus
    

    if(-not (Confirm-ContinueSetup)) {
        return
    }

    $selectedComponents = Show-SetupMenu
    
    if (-not $selectedComponents -or $selectedComponents.Count -eq 0) {
        Write-Host "Setup cancelled. No components selected." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "You selected the following components:" -ForegroundColor Cyan
    foreach ($component in $selectedComponents) {
        Write-Host "  • $component" -ForegroundColor White
    }
    Write-Host ""
    
    if (-not (Confirm-ProceedWithSetup)) {
        return
    }
    
    foreach ($component in $selectedComponents) {
        if ($script:SetupOptions.Contains($component)) {
            try {
                Invoke-SetupComponent -ComponentName $component `
                                     -ComponentInfo $script:SetupOptions[$component] `
                                     -RootDirectory $RootDirectory
            }
            catch {
                Write-Host "❌ Error setting up ${component}: $_" -ForegroundColor Red
                
                if (-not (Read-YesNo -Title "Continue with remaining components?" -DefaultYes $false)) {
                    break
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║            Setup Wizard Complete!                            ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# Execute main function
Start-InteractiveSetup -RootDirectory $RootDirectory