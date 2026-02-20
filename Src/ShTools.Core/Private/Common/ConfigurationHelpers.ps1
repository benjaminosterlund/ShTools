
function Find-ShToolsConfigFile {
    <#
    .SYNOPSIS
        Searches for shtools.config.json in standard locations

    .DESCRIPTION
        Searches for config file in the following order:
        1. Current directory
        2. Git repository root (if in a git repo)
        3. Parent directories (up to 5 levels)

    .OUTPUTS
        String path to config file, or $null if not found
    #>
    [CmdletBinding()]
    param()

    # 1. Check current directory
    $currentDirConfig = Join-Path $PWD "shtools.config.json"
    if (Test-Path $currentDirConfig) {
        Write-Verbose "Found config in current directory: $currentDirConfig"
        return $currentDirConfig
    }

    # 2. Check git root (if in a git repo)
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            # Convert Unix path to Windows path if needed
            $gitRoot = $gitRoot -replace '/', '\'
            $gitRootConfig = Join-Path $gitRoot "shtools.config.json"
            if (Test-Path $gitRootConfig) {
                Write-Verbose "Found config in git root: $gitRootConfig"
                return $gitRootConfig
            }
        }
    }
    catch {
        # Not in a git repo or git not available, continue searching
    }

    # 3. Check parent directories (up to 5 levels)
    $currentPath = $PWD
    for ($i = 0; $i -lt 5; $i++) {
        $parentPath = Split-Path $currentPath -Parent
        if (-not $parentPath) { break }

        $parentConfig = Join-Path $parentPath "shtools.config.json"
        if (Test-Path $parentConfig) {
            Write-Verbose "Found config in parent directory: $parentConfig"
            return $parentConfig
        }

        $currentPath = $parentPath
    }

    # Not found
    Write-Verbose "No shtools.config.json found in search paths"
    return $null
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Gets a specific value from config with fallback support

    .DESCRIPTION
        Retrieves a value from config, supporting:
        - Dot notation for nested properties (e.g., "github.owner")
        - Default value if not found
        - Environment variable override

    .PARAMETER Section
        Config section (github, localdb, dotnet)

    .PARAMETER Key
        Property key within the section

    .PARAMETER Default
        Default value if not found in config

    .PARAMETER EnvVar
        Environment variable name to check before config

    .EXAMPLE
        Get-ConfigValue -Section github -Key owner -Default "myorg"

    .EXAMPLE
        Get-ConfigValue -Section github -Key owner -EnvVar "SHTOOLS_GITHUB_OWNER" -Default "myorg"
        Checks $env:SHTOOLS_GITHUB_OWNER first, then config, then default
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('core', 'github', 'localdb', 'dotnet')]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter()]
        [object]$Default = $null,

        [Parameter()]
        [string]$EnvVar
    )

    # 1. Check environment variable (highest priority)
    if ($EnvVar -and (Test-Path "env:$EnvVar")) {
        $envValue = Get-Item "env:$EnvVar" | Select-Object -ExpandProperty Value
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            Write-Verbose "Using value from environment variable: $EnvVar"
            return $envValue
        }
    }

    # 2. Check config file
    $config = Get-ShToolsConfig -Section $Section
    if ($config -and $config.PSObject.Properties.Name -contains $Key) {
        $value = $config.$Key
        if ($null -ne $value -and $value -ne "") {
            Write-Verbose "Using value from config: $Section.$Key"
            return $value
        }
    }

    # 3. Use default
    Write-Verbose "Using default value for $Section.$Key"
    return $Default
}

function Test-ShToolsConfig {
    <#
    .SYNOPSIS
        Validates that required configuration exists

    .DESCRIPTION
        Checks if shtools.config.json exists and contains required values

    .PARAMETER Section
        Specific section to validate (github, localdb, dotnet)

    .PARAMETER Quiet
        Suppress warning messages

    .OUTPUTS
        Boolean - $true if config is valid, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('core', 'github', 'localdb', 'dotnet')]
        [string]$Section,

        [Parameter()]
        [switch]$Quiet
    )

    $configFile = Find-ShToolsConfigFile
    if (-not $configFile) {
        if (-not $Quiet) {
            Write-Warning "No shtools.config.json found. Run 'Initialize-ShToolsConfig' to create one."
        }
        return $false
    }

    $config = Get-ShToolsConfig
    if (-not $config) {
        if (-not $Quiet) {
            Write-Warning "Failed to load config from: $configFile"
        }
        return $false
    }

    # If specific section requested, validate it
    if ($Section) {
        if (-not ($config.PSObject.Properties.Name -contains $Section)) {
            if (-not $Quiet) {
                Write-Warning "Config section '$Section' not found in config"
            }
            return $false
        }

        # Section-specific validation
        switch ($Section) {
            'core' {
                return $true
            }
            'github' {
                $hasRequired = $config.github.owner -and
                               $config.github.repo -and
                               $config.github.projectNumber -gt 0
                if (-not $hasRequired -and -not $Quiet) {
                    Write-Warning "GitHub config incomplete. Required: owner, repo, projectNumber > 0"
                }
                return $hasRequired
            }
            'dotnet' {
                # Dotnet config is optional, just check it exists
                return $true
            }
            'localdb' {
                # Localdb config is optional (can auto-discover), just check it exists
                return $true
            }
        }
    }

    return $true
}
