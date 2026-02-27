function Get-SetupOptions {
    <#
    .SYNOPSIS
        Get available setup components and their script mappings.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return [ordered]@{
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
}

function Show-SetupWizardHeader {
    <#
    .SYNOPSIS
        Display the setup wizard header banner.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          ShTools Interactive Setup Wizard                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-SetupMenu {
    <#
    .SYNOPSIS
        Display multi-select menu for choosing setup components.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SetupOptions
    )

    

    Write-Host "📋 Select components to initialize (use Space to select, Enter to confirm):" -ForegroundColor Yellow
    Write-Host ""

    $menuItems = $SetupOptions.Keys | ForEach-Object {
        "$_ - $($SetupOptions[$_].Description)"
    }

    $selections = Show-Menu -MenuItems $menuItems -MultiSelect

    if (-not $selections -or $selections.Count -eq 0) {
        Write-Host "No components selected. Exiting." -ForegroundColor Yellow
        return @()
    }

    return $selections | ForEach-Object { $_ -replace ' - .*$', '' }
}

function Invoke-SetupComponent {
    <#
    .SYNOPSIS
        Execute setup for a specific component by calling its Init script.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComponentName,

        [Parameter(Mandatory)]
        [hashtable]$ComponentInfo,

        [Parameter(Mandatory)]
        [string]$RootDirectory,

        [Parameter(Mandatory)]
        [string]$ScriptsRoot
    )

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Setting up: $ComponentName" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $scriptPath = Join-Path $ScriptsRoot $ComponentInfo.Script

    if (Test-Path $scriptPath) {
        try {
            & $scriptPath -RootDirectory $RootDirectory
        }
        catch {
            throw "Failed to execute $scriptPath : $_"
        }
    }
    else {
        Write-Warning "Init script not found: $scriptPath"
        Write-Host "Expected: $scriptPath" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "✅ Completed: $ComponentName" -ForegroundColor Green
}
