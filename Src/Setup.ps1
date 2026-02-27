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
    [string]$RootDirectory = "..\"
)

$ErrorActionPreference = 'Stop'

# ===== MODULE INITIALIZATION =====
& (Join-Path $PSScriptRoot 'Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot
Import-PSMenuIfAvailable -ErrorAction SilentlyContinue | Out-Null


Show-SetupWizardHeader


$setupOptions = Get-SetupOptions

Show-SetupConfigurationStatus -RootDirectory $RootDirectory

if (-not (Confirm-ContinueSetup)) {
    return
}

$selectedComponents = Show-SetupMenu -SetupOptions $setupOptions

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
    if ($setupOptions.Contains($component)) {
        try {
            Invoke-SetupComponent -ComponentName $component `
                -ComponentInfo $setupOptions[$component] `
                -RootDirectory $RootDirectory `
                -ScriptsRoot $PSScriptRoot
        }
        catch {
            Write-Host "❌ Error setting up ${component}: $_" -ForegroundColor Red

            if (-not (Read-YesNo -Title "Continue with remaining components?" -DefaultYes $false)) {
                break
            }
        }
    }
}

Show-SetupCompleteBanner