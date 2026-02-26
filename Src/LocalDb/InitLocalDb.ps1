#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize LocalDb configuration for ShTools.
.DESCRIPTION
    Configures the project path used for LocalDb database operations in shtools.config.json.
    Can use the main .NET project or select a different one.
    Can be run interactively or with parameters for automation.
.PARAMETER RootDirectory
    Root directory to search for .csproj files (defaults to current directory)
.PARAMETER ProjectPath
    Path to project (.csproj file) to use for LocalDb operations
.PARAMETER UseMainProject
    Use the main .NET project path from dotnet configuration
.PARAMETER NonInteractive
    Run in non-interactive mode (requires ProjectPath or UseMainProject)
.EXAMPLE
    .\InitLocalDb.ps1
    
    Interactive mode - prompts to use main project or select different one
.EXAMPLE
    .\InitLocalDb.ps1 -UseMainProject
    
    Use the main .NET project for LocalDb
.EXAMPLE
    .\InitLocalDb.ps1 -ProjectPath "C:\MyProject\Data\Data.csproj"
    
    Use specific project for LocalDb operations
#>

[CmdletBinding()]
param(
    [string]$RootDirectory = $PWD,
    [string]$ProjectPath,
    [switch]$UseMainProject,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'

# Import ShTools module
$modulePath = Join-Path $PSScriptRoot "..\ShTools.Core\ShTools.Core.psd1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Error "ShTools.Core module not found at: $modulePath"
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           LocalDb Configuration Setup                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get config path
$configPath = Join-Path $RootDirectory "shtools.config.json"

# Load current config if exists
$currentConfig = Get-ShToolsConfig -ConfigPath $configPath -ErrorAction SilentlyContinue
$currentDotnet = if ($currentConfig -and $currentConfig.PSObject.Properties.Name -contains "dotnet") {
    $currentConfig.dotnet
} else {
    $null
}

$currentLocalDb = if ($currentConfig -and $currentConfig.PSObject.Properties.Name -contains "localdb") {
    $currentConfig.localdb
} else {
    [PSCustomObject]@{ projectPath = "" }
}

# Determine project path
if (-not $ProjectPath) {
    if ($NonInteractive -and -not $UseMainProject) {
        Write-Error "ProjectPath or UseMainProject is required in non-interactive mode"
        exit 1
    }
    
    Write-Host "Current LocalDb project: " -NoNewline -ForegroundColor Gray
    if ($currentLocalDb.projectPath) {
        Write-Host $currentLocalDb.projectPath -ForegroundColor White
    } else {
        Write-Host "(not set)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    if ($currentDotnet -and $currentDotnet.projectPath) {
        Write-Host "Main .NET project: " -NoNewline -ForegroundColor Gray
        Write-Host $currentDotnet.projectPath -ForegroundColor White
        Write-Host ""
    }
    
    if (-not $NonInteractive) {
        $useMain = Select-YesNo -Title "Use main .NET project for LocalDb?" -DefaultYes $true
        
        if ($useMain) {
            if ($currentDotnet -and $currentDotnet.projectPath) {
                $ProjectPath = $currentDotnet.projectPath
            } else {
                Write-Host "⚠️  Main .NET project not configured. Please select a project." -ForegroundColor Yellow
                Write-Host ""
                try {
                    $ProjectPath = Select-DotnetProject -SearchRoot $RootDirectory -Prompt "Select project for LocalDb"
                }
                catch {
                    Write-Host "Error selecting project: $_" -ForegroundColor Red
                    $ProjectPath = $currentLocalDb.projectPath
                }
            }
        } else {
            try {
                $ProjectPath = Select-DotnetProject -SearchRoot $RootDirectory -Prompt "Select project for LocalDb"
                if (-not $ProjectPath) {
                    Write-Host "No project selected, keeping current configuration." -ForegroundColor Yellow
                    $ProjectPath = $currentLocalDb.projectPath
                }
            }
            catch {
                Write-Host "Error selecting project: $_" -ForegroundColor Red
                $ProjectPath = $currentLocalDb.projectPath
            }
        }
    }
} elseif ($UseMainProject) {
    if ($currentDotnet -and $currentDotnet.projectPath) {
        $ProjectPath = $currentDotnet.projectPath
    } else {
        Write-Error "Main .NET project not configured. Run InitDotnet.ps1 first or specify -ProjectPath"
        exit 1
    }
}

if (-not $ProjectPath) {
    Write-Host "❌ No LocalDb project path specified. Configuration not saved." -ForegroundColor Yellow
    exit 0
}

# Save configuration
Write-Host ""
Write-Host "Saving LocalDb configuration..." -ForegroundColor Cyan

$localDbConfig = @{
    projectPath = $ProjectPath
}

try {
    Set-ShToolsConfig -ConfigPath $configPath -Section localdb -Values $localDbConfig
    
    Write-Host ""
    Write-Host "✅ LocalDb configuration saved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  LocalDb project: " -NoNewline -ForegroundColor Gray
    Write-Host $ProjectPath -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host "❌ Failed to save configuration: $_" -ForegroundColor Red
    exit 1
}
