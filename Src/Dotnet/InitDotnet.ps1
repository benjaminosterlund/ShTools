#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize .NET project configuration for ShTools.
.DESCRIPTION
    Configures .NET project paths in shtools.config.json.
    Allows selection of main project and test projects.
    Can be run interactively or with parameters for automation.
.PARAMETER RootDirectory
    Root directory to search for .csproj files (defaults to current directory)
.PARAMETER ProjectPath
    Path to main .NET project (.csproj file)
.PARAMETER TestProjectPath
    Path(s) to test project(s) (.csproj files)
.PARAMETER NonInteractive
    Run in non-interactive mode (requires ProjectPath parameter)
.EXAMPLE
    .\InitDotnet.ps1
    
    Interactive mode - prompts to select projects
.EXAMPLE
    .\InitDotnet.ps1 -ProjectPath "C:\MyProject\MyProject.csproj"
    
    Set main project path directly
.EXAMPLE
    .\InitDotnet.ps1 -ProjectPath "src\Api.csproj" -TestProjectPath "tests\Api.Tests.csproj"
    
    Set both main and test project paths
#>

[CmdletBinding()]
param(
    [string]$RootDirectory = $PWD,
    [string]$ProjectPath,
    [string[]]$TestProjectPath,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'

# Import ShTools module
& (Join-Path $PSScriptRoot '..\Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        .NET Project Configuration Setup                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get config path
$configPath = Join-Path $RootDirectory "shtools.config.json"

# Load current config if exists
$currentConfig = Get-ShToolsConfig -ConfigPath $configPath -ErrorAction SilentlyContinue
$currentDotnet = if ($currentConfig -and $currentConfig.PSObject.Properties.Name -contains "dotnet") {
    $currentConfig.dotnet
} else {
    [PSCustomObject]@{
        projectPath = ""
        testProjectPath = @()
        searchRoot = ""
    }
}

# Determine project path
if (-not $ProjectPath) {
    if ($NonInteractive) {
        Write-Error "ProjectPath is required in non-interactive mode"
        exit 1
    }
    
    Write-Host "Current main project: " -NoNewline -ForegroundColor Gray
    if ($currentDotnet.projectPath) {
        Write-Host $currentDotnet.projectPath -ForegroundColor White
    } else {
        Write-Host "(not set)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    if (Select-YesNo -Title "Select main .NET project?" -DefaultYes $true) {
        try {
            $ProjectPath = Select-DotnetProject -SearchRoot $RootDirectory -Prompt "Select main .NET project"
            if (-not $ProjectPath) {
                Write-Host "No project selected, keeping current configuration." -ForegroundColor Yellow
                $ProjectPath = $currentDotnet.projectPath
            }
        }
        catch {
            Write-Host "Error selecting project: $_" -ForegroundColor Red
            $ProjectPath = $currentDotnet.projectPath
        }
    } else {
        $ProjectPath = $currentDotnet.projectPath
    }
}

# Determine test project paths
if (-not $TestProjectPath -and -not $NonInteractive) {
    Write-Host ""
    Write-Host "Current test projects: " -NoNewline -ForegroundColor Gray
    if ($currentDotnet.testProjectPath -and $currentDotnet.testProjectPath.Count -gt 0) {
        Write-Host ""
        $currentDotnet.testProjectPath | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor White
        }
    } else {
        Write-Host "(not set)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    if (Select-YesNo -Title "Select test .NET project(s)?" -DefaultYes $false) {
        try {
            $TestProjectPath = Select-DotnetProjects -SearchRoot $RootDirectory -Prompt "Select test .NET project(s)"
            if (-not $TestProjectPath) {
                Write-Host "No test projects selected, keeping current configuration." -ForegroundColor Yellow
                $TestProjectPath = $currentDotnet.testProjectPath
            }
        }
        catch {
            Write-Host "Error selecting test projects: $_" -ForegroundColor Red
            $TestProjectPath = $currentDotnet.testProjectPath
        }
    } else {
        $TestProjectPath = $currentDotnet.testProjectPath
    }
}

# Ensure TestProjectPath is an array
if (-not $TestProjectPath) {
    $TestProjectPath = @()
}

# Save configuration
Write-Host ""
Write-Host "Saving .NET configuration..." -ForegroundColor Cyan

$dotnetConfig = @{
    projectPath = $ProjectPath
    testProjectPath = @($TestProjectPath)
    searchRoot = $RootDirectory
}

try {
    Set-ShToolsConfig -ConfigPath $configPath -Section dotnet -Values $dotnetConfig
    
    Write-Host ""
    Write-Host "✅ .NET project configuration saved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Main project: " -NoNewline -ForegroundColor Gray
    Write-Host $ProjectPath -ForegroundColor White
    
    if ($TestProjectPath -and $TestProjectPath.Count -gt 0) {
        Write-Host "  Test projects:" -ForegroundColor Gray
        $TestProjectPath | ForEach-Object {
            Write-Host "    - $_" -ForegroundColor White
        }
    }
    
    Write-Host "  Search root: " -NoNewline -ForegroundColor Gray
    Write-Host $RootDirectory -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host "❌ Failed to save configuration: $_" -ForegroundColor Red
    exit 1
}
