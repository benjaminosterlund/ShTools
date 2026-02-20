
function Get-ShToolsConfig {
    <#
    .SYNOPSIS
        Retrieves configuration values from shtools.config.json

    .DESCRIPTION
        Searches for shtools.config.json in the following order:
        1. Specified ConfigPath parameter
        2. Current directory
        3. Git repository root (if in a git repo)

        Returns the full config or a specific section.

    .PARAMETER ConfigPath
        Explicit path to config file. If not specified, searches default locations.

    .PARAMETER Section
        Specific section to return (github, localdb, dotnet). If not specified, returns full config.

    .EXAMPLE
        Get-ShToolsConfig
        Returns the full configuration object

    .EXAMPLE
        Get-ShToolsConfig -Section github
        Returns just the github configuration section

    .EXAMPLE
        Get-ShToolsConfig -ConfigPath "C:\MyProject\shtools.config.json"
        Returns config from specific file
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,

        [Parameter()]
        [ValidateSet('core', 'github', 'localdb', 'dotnet')]
        [string]$Section
    )

    # Find config file
    $configFile = if ($ConfigPath) {
        if (-not (Test-Path $ConfigPath)) {
            Write-Warning "Config file not found at: $ConfigPath"
            return $null
        }
        $ConfigPath
    } else {
        Find-ShToolsConfigFile
    }

    if (-not $configFile) {
        Write-Warning "No shtools.config.json found. Run 'Initialize-ShToolsConfig' to create one."
        return $null
    }

    # Load and parse config
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json

        # Return specific section or full config
        if ($Section) {
            if ($config.PSObject.Properties.Name -contains $Section) {
                return $config.$Section
            } else {
                Write-Warning "Section '$Section' not found in config"
                return $null
            }
        }

        return $config
    }
    catch {
        Write-Error "Failed to load config from ${configFile}: $_"
        return $null
    }
}

function Set-ShToolsConfig {
    <#
    .SYNOPSIS
        Sets configuration values in shtools.config.json

    .DESCRIPTION
        Updates or creates configuration values in shtools.config.json.
        Can update specific sections or individual properties.

    .PARAMETER ConfigPath
        Path to config file. If not specified, searches default locations.
        If no config exists, creates one in current directory.

    .PARAMETER Section
        Section to update (github, localdb, dotnet)

    .PARAMETER Values
        Hashtable of values to set in the section

    .EXAMPLE
        Set-ShToolsConfig -Section github -Values @{ owner = "myorg"; repo = "myrepo"; projectNumber = 1 }

    .EXAMPLE
        Set-ShToolsConfig -Section dotnet -Values @{ projectPath = "C:\MyProject\MyProject.csproj" }
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [ValidateSet('core', 'github', 'localdb', 'dotnet')]
        [string]$Section,

        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    # Find or create config file
    $configFile = if ($ConfigPath) {
        $ConfigPath
    } else {
        $existing = Find-ShToolsConfigFile
        if ($existing) {
            $existing
        } else {
            Join-Path $PWD "shtools.config.json"
        }
    }

    # Load existing config or create new
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "Failed to load existing config: $_"
            return
        }
    } else {
        # Create new config with default structure
        $config = [PSCustomObject]@{
            core = [PSCustomObject]@{
                version = "1.0"
                lastUpdate = ""
                scriptsFolder = ""
                autoUpdate = $true
            }
            github = [PSCustomObject]@{
                owner = ""
                repo = ""
                projectNumber = 0
                _cache = [PSCustomObject]@{}
            }
            localdb = [PSCustomObject]@{
                projectPath = ""
            }
            dotnet = [PSCustomObject]@{
                projectPath = ""
                testProjectPath = @()
                searchRoot = ""
            }
        }
    }

    # Update the specified section
    # Ensure the section exists and is not null
    if ($null -eq $config.$Section -or -not $config.PSObject.Properties.Name -contains $Section) {
        # Section doesn't exist or is null, create it
        $config | Add-Member -MemberType NoteProperty -Name $Section -Value ([PSCustomObject]@{}) -Force
    }

    # Update/add values in section
    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        if ($config.$Section.PSObject.Properties.Name -contains $key) {
            # Update existing property
            $config.$Section.$key = $value
        } else {
            # Add new property
            $config.$Section | Add-Member -MemberType NoteProperty -Name $key -Value $value
        }
    }

    # Save config
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
        Write-Host "✓ Configuration updated: $configFile" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to save config to ${configFile}: $_"
    }
}

function Initialize-ShToolsConfig {
    <#
    .SYNOPSIS
        Interactively creates or updates shtools.config.json

    .DESCRIPTION
        Guides the user through setting up their shtools.config.json file.
        Prompts for GitHub project info, .NET project paths, etc.

    .PARAMETER ConfigPath
        Path where config file should be created. Defaults to current directory.

    .PARAMETER Force
        Overwrite existing config file without prompting

    .EXAMPLE
        Initialize-ShToolsConfig
        Interactively creates config in current directory

    .EXAMPLE
        Initialize-ShToolsConfig -ConfigPath "C:\MyProject\shtools.config.json" -Force
        Creates config at specific location, overwriting if exists
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = (Join-Path $PWD "shtools.config.json"),

        [Parameter()]
        [switch]$Force
    )

    Write-Host "=== ShTools Configuration Setup ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if config exists
    if ((Test-Path $ConfigPath) -and -not $Force) {
        $overwrite = Read-Host "Config file already exists at $ConfigPath. Overwrite? (y/N)"
        if ($overwrite -notmatch '^[Yy]') {
            Write-Host "Configuration setup cancelled." -ForegroundColor Yellow
            return
        }
    }

    # Initialize config structure
    $config = @{
        github = @{}
        localdb = @{}
        dotnet = @{}
    }

    # GitHub configuration
    Write-Host "GitHub Projects Configuration" -ForegroundColor Cyan
    $configureGitHub = Read-Host "Configure GitHub Projects? (Y/n)"
    if ($configureGitHub -match '^[Yy]' -or [string]::IsNullOrWhiteSpace($configureGitHub)) {
        $config.github.owner = Read-Host "  GitHub owner (user or org)"
        $config.github.repo = Read-Host "  Repository name"
        $projectNum = Read-Host "  Project number"
        $config.github.projectNumber = if ($projectNum) { [int]$projectNum } else { 0 }
        $config.github._cache = @{}
    } else {
        $config.github = @{ owner = ""; repo = ""; projectNumber = 0; _cache = @{} }
    }

    Write-Host ""

    # .NET Projects configuration
    Write-Host ".NET Projects Configuration" -ForegroundColor Cyan
    $configureDotnet = Read-Host "Configure .NET project paths? (Y/n)"
    if ($configureDotnet -match '^[Yy]' -or [string]::IsNullOrWhiteSpace($configureDotnet)) {

        # Try to auto-discover projects
        Write-Host "  Searching for .csproj files..." -ForegroundColor Gray
        $projects = Get-ChildItem -Path $PWD -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 10

        if ($projects) {
            Write-Host "  Found $($projects.Count) project(s):" -ForegroundColor Gray
            for ($i = 0; $i -lt $projects.Count; $i++) {
                Write-Host "    [$i] $($projects[$i].FullName)" -ForegroundColor Gray
            }

            $selection = Read-Host "  Select main project [0-$($projects.Count - 1)] or enter custom path"
            if ($selection -match '^\d+$' -and [int]$selection -lt $projects.Count) {
                $config.dotnet.projectPath = $projects[[int]$selection].FullName
            } else {
                $config.dotnet.projectPath = $selection
            }

            $testSelection = Read-Host "  Select test project [0-$($projects.Count - 1)] or enter custom path (leave empty to skip)"
            if ($testSelection -match '^\d+$' -and [int]$testSelection -lt $projects.Count) {
                $config.dotnet.testProjectPath = @($projects[[int]$testSelection].FullName)
            } elseif (-not [string]::IsNullOrWhiteSpace($testSelection)) {
                $config.dotnet.testProjectPath = @($testSelection)
            } else {
                $config.dotnet.testProjectPath = @()
            }
        } else {
            Write-Host "  No .csproj files found in current directory" -ForegroundColor Yellow
            $mainProject = Read-Host "  Main project path (leave empty to skip)"
            $config.dotnet.projectPath = $mainProject

            $testProject = Read-Host "  Test project path (leave empty to skip)"
            $config.dotnet.testProjectPath = if ($testProject) { @($testProject) } else { @() }
        }

        $searchRoot = Read-Host "  Search root for project discovery (leave empty for current directory)"
        $config.dotnet.searchRoot = $searchRoot
    } else {
        $config.dotnet = @{ projectPath = ""; testProjectPath = @(); searchRoot = "" }
    }

    Write-Host ""

    # LocalDb configuration
    Write-Host "LocalDb Configuration" -ForegroundColor Cyan
    $useMainProject = Read-Host "Use main .NET project for LocalDb? (Y/n)"
    if ($useMainProject -match '^[Yy]' -or [string]::IsNullOrWhiteSpace($useMainProject)) {
        $config.localdb.projectPath = $config.dotnet.projectPath
    } else {
        $dbProject = Read-Host "  Project path for database operations (leave empty to skip)"
        $config.localdb.projectPath = $dbProject
    }

    Write-Host ""

    # Save configuration
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        Write-Host "✓ Configuration saved to: $ConfigPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can edit this file manually or run Initialize-ShToolsConfig again to reconfigure." -ForegroundColor Gray
    }
    catch {
        Write-Error "Failed to save configuration: $_"
    }
}
