function Set-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,
        [string]$ToolingDirectory
    )

    $configFilePath = Join-Path -Path $RootDirectory -ChildPath "shtools.config.json"
    $toolingDirName = Split-Path -Path $ToolingDirectory -Leaf

    $configPath = Join-Path $RootDirectory "shtools.config.json"

    if (Test-Path $configPath) {
        Write-Host "Configuration file exists: $configPath" -ForegroundColor Gray
        return
    }

    if ((Read-Host "Would you like to create a configuration file now? (Y/n)" -Default "Y") -match '^[Yy]') {

        $projectPath = $null
        $testProjectPath = $null

        if ((Read-Host "Configure .NET projects? (Y/n)" -Default "Y") -match '^[Yy]') {
            $projectPath = Select-DotnetProject -Prompt "Select main .NET project"
            $testProjectPath = Select-DotnetProjects -Prompt "Select test .NET project(s)"
        }

        $config = @{
            version         = "1.0"
            lastUpdate      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            scriptsFolder   = $ToolingDirectory
            autoUpdate      = $true
            projectPath     = $projectPath
            testProjectPath = @($testProjectPath)
        }

        $config | ConvertTo-Json | Set-Content -Path:$configPath
        Write-Host "✓ Configuration file created: $configPath" -ForegroundColor Green
    }
}
