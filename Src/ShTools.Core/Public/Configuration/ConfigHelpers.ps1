
function Get-DotnetProjectPath {
    <#
    .SYNOPSIS
        Gets the .NET project path from config or interactive selection

    .DESCRIPTION
        Retrieves the .NET project path using this precedence:
        1. Explicit -ProjectPath parameter
        2. Config file (dotnet.projectPath)
        3. Interactive selection (Select-DotnetProject)

        Optionally saves the selected path back to config.

    .PARAMETER ProjectPath
        Explicit project path. If provided, skips config and selection.

    .PARAMETER SaveToConfig
        If true, saves the selected project path to config file

    .PARAMETER SearchRoot
        Root directory to search for .csproj files. Defaults to config or current directory.

    .PARAMETER Prompt
        Prompt message for interactive selection. Default: "Select .NET project"

    .EXAMPLE
        Get-DotnetProjectPath
        Gets project path from config, or prompts if not configured

    .EXAMPLE
        Get-DotnetProjectPath -SaveToConfig
        Gets project path and saves selection to config

    .EXAMPLE
        Get-DotnetProjectPath -ProjectPath "C:\MyProject\MyProject.csproj"
        Uses explicit path, bypassing config and selection
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectPath,

        [Parameter()]
        [switch]$SaveToConfig,

        [Parameter()]
        [string]$SearchRoot,

        [Parameter()]
        [string]$Prompt = "Select .NET project"
    )

    # 1. Use explicit parameter if provided
    if ($ProjectPath) {
        if (Test-Path $ProjectPath -PathType Leaf) {
            Write-Verbose "Using explicit project path: $ProjectPath"
            return (Resolve-Path $ProjectPath).Path
        }
        throw "ProjectPath '$ProjectPath' does not exist or is not a file."
    }

    # 2. Try to get from config
    $configPath = Get-ConfigValue -Section dotnet -Key projectPath
    if ($configPath -and (Test-Path $configPath -PathType Leaf)) {
        Write-Verbose "Using project path from config: $configPath"
        return (Resolve-Path $configPath).Path
    }

    # 3. Fall back to interactive selection
    Write-Host "No project path configured. " -NoNewline -ForegroundColor Yellow
    Write-Host "Searching for .csproj files..." -ForegroundColor Gray

    $searchPath = if ($SearchRoot) {
        $SearchRoot
    } else {
        Get-ConfigValue -Section dotnet -Key searchRoot -Default $PWD
    }

    $selectedPath = Select-DotnetProject -SearchRoot $searchPath -Prompt $Prompt

    # 4. Optionally save to config
    if ($SaveToConfig -and $selectedPath) {
        Write-Host "Saving project path to config..." -ForegroundColor Gray
        Set-ShToolsConfig -Section dotnet -Values @{ projectPath = $selectedPath }
    }

    return $selectedPath
}

function Get-DotnetProjectPaths {
    <#
    .SYNOPSIS
        Gets multiple .NET project paths (e.g., test projects)

    .DESCRIPTION
        Retrieves .NET project paths using this precedence:
        1. Explicit -ProjectPath parameter
        2. Config file (dotnet.testProjectPath)
        3. Interactive multi-selection (Select-DotnetProjects)

    .PARAMETER ProjectPath
        Explicit project paths. If provided, skips config and selection.

    .PARAMETER SaveToConfig
        If true, saves the selected project paths to config file

    .PARAMETER ConfigKey
        Config key to read/write. Default: "testProjectPath"

    .PARAMETER SearchRoot
        Root directory to search for .csproj files

    .PARAMETER Prompt
        Prompt message for interactive selection

    .EXAMPLE
        Get-DotnetProjectPaths
        Gets test project paths from config or prompts if not configured

    .EXAMPLE
        Get-DotnetProjectPaths -SaveToConfig -ConfigKey "testProjectPath"
        Gets test projects and saves to config
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ProjectPath,

        [Parameter()]
        [switch]$SaveToConfig,

        [Parameter()]
        [string]$ConfigKey = "testProjectPath",

        [Parameter()]
        [string]$SearchRoot,

        [Parameter()]
        [string]$Prompt = "Select .NET project(s)"
    )

    # 1. Use explicit parameter if provided
    if ($ProjectPath) {
        $resolved = foreach ($p in $ProjectPath) {
            if (-not (Test-Path $p -PathType Leaf)) {
                throw "ProjectPath '$p' does not exist or is not a file."
            }
            (Resolve-Path $p).Path
        }
        Write-Verbose "Using explicit project paths: $($resolved -join ', ')"
        return @($resolved)
    }

    # 2. Try to get from config
    $config = Get-ShToolsConfig -Section dotnet
    if ($config -and $config.PSObject.Properties.Name -contains $ConfigKey) {
        $configPaths = $config.$ConfigKey
        if ($configPaths -and $configPaths.Count -gt 0) {
            $validPaths = $configPaths | Where-Object { Test-Path $_ -PathType Leaf }
            if ($validPaths) {
                Write-Verbose "Using project paths from config: $($validPaths -join ', ')"
                return @($validPaths)
            }
        }
    }

    # 3. Fall back to interactive selection
    Write-Host "No $ConfigKey configured. " -NoNewline -ForegroundColor Yellow
    Write-Host "Searching for .csproj files..." -ForegroundColor Gray

    $searchPath = if ($SearchRoot) {
        $SearchRoot
    } else {
        Get-ConfigValue -Section dotnet -Key searchRoot -Default $PWD
    }

    $selectedPaths = Select-DotnetProjects -SearchRoot $searchPath -Prompt $Prompt

    # 4. Optionally save to config
    if ($SaveToConfig -and $selectedPaths) {
        Write-Host "Saving project paths to config..." -ForegroundColor Gray
        Set-ShToolsConfig -Section dotnet -Values @{ $ConfigKey = @($selectedPaths) }
    }

    return @($selectedPaths)
}

function Get-GitHubProjectConfig {
    <#
    .SYNOPSIS
        Gets GitHub project configuration with validation

    .DESCRIPTION
        Retrieves GitHub project configuration (owner, repo, projectNumber).
        Validates that required values are present.
        Returns $null if validation fails.

    .PARAMETER Owner
        Explicit GitHub owner. If provided, skips config lookup.

    .PARAMETER Repo
        Explicit repository name. If provided, skips config lookup.

    .PARAMETER ProjectNumber
        Explicit project number. If provided, skips config lookup.

    .PARAMETER Required
        If true, throws error if config is invalid. If false, returns $null.

    .EXAMPLE
        $ghConfig = Get-GitHubProjectConfig
        if ($ghConfig) {
            Write-Host "Owner: $($ghConfig.owner)"
        }

    .EXAMPLE
        $ghConfig = Get-GitHubProjectConfig -Required
        Throws error if GitHub config is not valid
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Owner,

        [Parameter()]
        [string]$Repo,

        [Parameter()]
        [int]$ProjectNumber,

        [Parameter()]
        [switch]$Required
    )

    # Build config from parameters or config file
    $config = [PSCustomObject]@{
        owner = if ($Owner) {
            $Owner
        } else {
            Get-ConfigValue -Section github -Key owner -EnvVar "SHTOOLS_GITHUB_OWNER"
        }
        repo = if ($Repo) {
            $Repo
        } else {
            Get-ConfigValue -Section github -Key repo -EnvVar "SHTOOLS_GITHUB_REPO"
        }
        projectNumber = if ($ProjectNumber) {
            $ProjectNumber
        } else {
            $pn = Get-ConfigValue -Section github -Key projectNumber -EnvVar "SHTOOLS_GITHUB_PROJECT_NUMBER" -Default 0
            if ($pn -is [string]) { [int]$pn } else { $pn }
        }
        _cache = (Get-ShToolsConfig -Section github)._cache
    }

    # Validate required fields
    $isValid = $config.owner -and
               $config.repo -and
               $config.projectNumber -gt 0

    if (-not $isValid) {
        $message = "GitHub project not configured. Run 'Initialize-ShToolsConfig' or set: owner, repo, projectNumber > 0"
        if ($Required) {
            throw $message
        } else {
            Write-Warning $message
            return $null
        }
    }

    return $config
}
