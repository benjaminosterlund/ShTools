function Get-ConfigurationStatus {
    <#
    .SYNOPSIS
        Get dynamic configuration status for all sections.
    .DESCRIPTION
        Analyzes shtools.config.json and returns status for all configured sections.
        Extensible - automatically handles new sections without code changes.
    .PARAMETER RootDirectory
        Root directory where shtools.config.json is located (defaults to current directory)
    .OUTPUTS
        Hashtable with configuration status
    .EXAMPLE
        $status = Get-ConfigurationStatus
        Show-ConfigurationStatus -Status $status
    .EXAMPLE
        $status = Get-ConfigurationStatus -RootDirectory "C:\MyProject"
    #>
    [CmdletBinding()]
    param([string]$RootDirectory = $PWD)
    
    $status = @{
        IsGitRepository = Test-Path (Join-Path $RootDirectory ".git")
        HasConfigFile = $false
        Sections = @{}  # Dynamic section status
    }
    
    $configPath = Join-Path $RootDirectory "shtools.config.json"
    $status.HasConfigFile = Test-Path $configPath
    
    if ($status.HasConfigFile) {
        try {
            $config = Get-ShToolsConfig -ConfigPath $configPath
            
            # Dynamically check each known section
            $knownSections = @('core', 'github', 'dotnet', 'localdb', 'docker', 'azure', 'kubernetes')
            
            foreach ($section in $knownSections) {
                if ($config.PSObject.Properties.Name -contains $section) {
                    $status.Sections[$section] = Test-ConfigSection -Section $section -Config $config
                }
            }
            
            # Also include any unknown sections
            foreach ($prop in $config.PSObject.Properties) {
                if ($prop.Name -notin $knownSections -and $prop.Name -notin $status.Sections.Keys) {
                    $status.Sections[$prop.Name] = $true  # Unknown sections considered valid if they exist
                }
            }
        }
        catch {
            Write-Verbose "Error reading config: $_"
        }
    }
    
    return $status
}

function Test-ConfigSection {
    <#
    .SYNOPSIS
        Test if a configuration section is properly configured.
    .DESCRIPTION
        Validates configuration sections based on their expected properties.
        Extensible - add new sections in the switch statement.
    .PARAMETER Section
        Section name to validate
    .PARAMETER Config
        Configuration object
    .OUTPUTS
        Boolean indicating if section is properly configured
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Section,
        
        [Parameter(Mandatory)]
        [object]$Config
    )
    
    switch ($Section) {
        'github' { 
            return ($Config.github.owner -and 
                   $Config.github.repo -and 
                   $Config.github.projectNumber -gt 0)
        }
        'dotnet' { 
            return ($Config.dotnet.projectPath -and 
                   (Test-Path $Config.dotnet.projectPath -ErrorAction SilentlyContinue))
        }
        'localdb' { 
            return ($Config.localdb.projectPath -and 
                   (Test-Path $Config.localdb.projectPath -ErrorAction SilentlyContinue))
        }
        'core' {
            return ($Config.core.version -and $Config.core.scriptsFolder)
        }
        'docker' {
            return ($Config.docker.dockerfilePath -and 
                   (Test-Path $Config.docker.dockerfilePath -ErrorAction SilentlyContinue))
        }
        'azure' {
            return ($Config.azure.resourceGroup -and $Config.azure.subscriptionId)
        }
        'kubernetes' {
            return ($Config.kubernetes.contextName -and $Config.kubernetes.namespace)
        }
        default { 
            # Unknown sections considered valid if they exist
            return $true
        }
    }
}

function Show-ConfigurationStatus {
    <#
    .SYNOPSIS
        Display configuration status with dynamic sections.
    .DESCRIPTION
        Shows formatted configuration status for all sections.
        Automatically adapts to new sections without code changes.
    .PARAMETER Status
        Status hashtable from Get-ConfigurationStatus
    .EXAMPLE
        $status = Get-ConfigurationStatus
        Show-ConfigurationStatus -Status $status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Status
    )
    
    # Define friendly names for sections
    $sectionNames = @{
        'core' = 'Core ShTools Settings'
        'github' = 'GitHub Project'
        'dotnet' = '.NET Project Settings'
        'localdb' = 'LocalDb Settings'
        'docker' = 'Docker Configuration'
        'azure' = 'Azure Configuration'
        'kubernetes' = 'Kubernetes Configuration'
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Current Configuration Status" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Helper to show status line
    $showStatusLine = {
        param([string]$Label, [bool]$IsConfigured, [string]$AdditionalInfo = "")
        
        $symbol = if ($IsConfigured) { "✅" } else { "⚠️ " }
        $text = if ($IsConfigured) { "Configured" } else { "Not configured" }
        $color = if ($IsConfigured) { "Green" } else { "Yellow" }
        
        Write-Host "  $symbol " -NoNewline
        Write-Host "$Label`: " -NoNewline -ForegroundColor White
        Write-Host $text -ForegroundColor $color
        
        if ($AdditionalInfo) {
            Write-Host "      $AdditionalInfo" -ForegroundColor Gray
        }
    }
    
    # Git Repository
    & $showStatusLine "Git Repository" $Status.IsGitRepository
    
    # Config File
    & $showStatusLine "Config File (shtools.config.json)" $Status.HasConfigFile
    
    # Dynamic sections (sorted for consistent display)
    if ($Status.Sections.Count -gt 0) {
        foreach ($section in ($Status.Sections.Keys | Sort-Object)) {
            $friendlyName = if ($sectionNames.ContainsKey($section)) { 
                $sectionNames[$section] 
            } else { 
                # Convert section name to Title Case if no friendly name
                (Get-Culture).TextInfo.ToTitleCase($section)
            }
            
            $isConfigured = $Status.Sections[$section]
            & $showStatusLine $friendlyName $isConfigured
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}
