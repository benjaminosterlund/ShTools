function Set-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,
        [string]$ToolingDirectory
    )

    $configPath = Join-Path $RootDirectory "shtools.config.json"

  
    if (-not (Initialize-ConfigFile -Path $configPath)) {
        return
    }

    $menuOptions = @(
        "Core settings",
        "GitHub settings",
        ".NET settings",
        "LocalDb settings",
        "Save and exit"
    )

    while ($true) {
        $currentConfig = Get-ShToolsConfig -ConfigPath $configPath
        $selection = Show-MenuWithTitle -Title "ShTools configuration" -Options $menuOptions

        switch ($selection) {
            "Core settings" { Update-CoreSection -ConfigPath $configPath -ToolingDirectory $ToolingDirectory -CurrentConfig $currentConfig }
            "GitHub Projects settings" { Update-GitHubSection -ConfigPath $configPath -CurrentConfig $currentConfig }
            ".NET settings" { Update-DotnetSection -ConfigPath $configPath -CurrentConfig $currentConfig -RootDirectory $RootDirectory }
            "LocalDb settings" { Update-LocalDbSection -ConfigPath $configPath -CurrentConfig $currentConfig -RootDirectory $RootDirectory }
            "Save and exit" { break }
            default { break }
        }
    }
}




  function Show-MenuWithTitle {
        param(
            [Parameter(Mandatory)]
            [string]$Title,

            [Parameter(Mandatory)]
            [object[]]$Options
        )

        Write-Host ""
        Write-Host $Title -ForegroundColor Yellow
        
        $cmd = Get-Command Show-Menu -ErrorAction SilentlyContinue
        if (-not $cmd) {
            throw "PSMenu is installed but Show-Menu was not found."
        }

        # PSMenu's Show-Menu uses pipeline input or -MenuItems
        if ($cmd.Parameters.ContainsKey('MenuItems')) {
            return Show-Menu -MenuItems $Options
        }

        return $Options | Show-Menu 
    }

    function Initialize-ConfigFile {
        param([string]$Path)

        if (Test-Path $Path) {
            return $true
        }

        $choice = Show-MenuWithTitle -Title "Config file not found. Create shtools.config.json?" -Options @("Yes", "No")
        if ($choice -ne "Yes") {
            Write-Host "Configuration file creation skipped." -ForegroundColor Yellow
            return $false
        }

        $defaultConfig = [PSCustomObject]@{
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

        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        return $true
    }

    function Read-Value {
        param(
            [string]$Prompt,
            [object]$CurrentValue
        )

        $suffix = if ($null -ne $CurrentValue -and $CurrentValue -ne "") { " [$CurrentValue]" } else { "" }
        $inputValue = Read-Host "$Prompt$suffix"
        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            return $CurrentValue
        }

        return $inputValue
    }

    function Read-YesNo {
        param(
            [string]$Title,
            [bool]$DefaultYes = $true
        )

        $choice = Show-MenuWithTitle -Title $Title -Options @("Yes", "No")
        if (-not $choice) {
            return $DefaultYes
        }

        return ($choice -eq "Yes")
    }

    function Update-CoreSection {
        param(
            [string]$ConfigPath,
            [string]$ToolingDirectory,
            [object]$CurrentConfig
        )

        $currentCore = if ($CurrentConfig -and $CurrentConfig.PSObject.Properties.Name -contains "core") {
            $CurrentConfig.core
        } else {
            [PSCustomObject]@{}
        }

        $autoUpdateDefault = $true
        if ($null -ne $currentCore.autoUpdate) {
            $autoUpdateDefault = [bool]$currentCore.autoUpdate
        }

        $autoUpdate = Read-YesNo -Title "Enable auto updates?" -DefaultYes $autoUpdateDefault
        $scriptsFolder = if ($ToolingDirectory) { $ToolingDirectory } else { $currentCore.scriptsFolder }
        if (-not $scriptsFolder) {
            $scriptsFolder = Read-Value -Prompt "Scripts folder" -CurrentValue $currentCore.scriptsFolder
        }

        Set-ShToolsConfig -ConfigPath $ConfigPath -Section core -Values @{
            version = "1.0"
            lastUpdate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            scriptsFolder = $scriptsFolder
            autoUpdate = $autoUpdate
        }
    }

    function Update-GitHubSection {
        param(
            [string]$ConfigPath,
            [object]$CurrentConfig,
            [string]$Owner,
            [string]$Repo, 
            [int]$ProjectNumber
        )




        if($Owner -and $Repo -and $ProjectNumber) {
            Write-Host "Using provided parameters for configuration." -ForegroundColor Green
            Set-ShToolsConfig -ConfigPath $ConfigPath -Section github -Values @{
                    owner = $Owner
                    repo = $Repo
                    projectNumber = $ProjectNumber
                }
            return
        } 


        if (-not $Owner -or -not $Repo -or -not $ProjectNumber) {
            Write-Host "`nTo set up automation, I need some information about your GitHub project:" -ForegroundColor Yellow
        }

        if (-not $Owner) {
            $Owner = Read-Host "GitHub repository owner/organization"
            if (-not $Owner.Trim()) {
                Write-Host "Owner cannot be empty!" -ForegroundColor Red
                exit 1
            }
        }

        if (-not $Repo) {
            $Repo = Read-Host "Repository name (without owner prefix)"
            if (-not $Repo.Trim()) {
                Write-Host "Repository name cannot be empty!" -ForegroundColor Red
                exit 1
            }
        }

        if (-not $ProjectNumber) {
            Write-Host "`nYou can find the project number in the project URL:" -ForegroundColor Gray
            Write-Host "https://github.com/users/$Owner/projects/[PROJECT_NUMBER]" -ForegroundColor Gray
            do {
                $projectInput = Read-Host "GitHub Project number"
                if ($projectInput -and $projectInput -match '^\d+$') {
                    $ProjectNumber = [int]$projectInput
                } else {
                    Write-Host "Please enter a valid project number." -ForegroundColor Red
                }
            } while (-not $ProjectNumber)
        }

        Write-Host "`n📋 Configuration Summary:" -ForegroundColor Yellow
        Write-Host "Owner: $Owner" -ForegroundColor White
        Write-Host "Repository: $Repo" -ForegroundColor White  
        Write-Host "Project Number: $ProjectNumber" -ForegroundColor White
        Write-Host "Full Repository: $Owner/$Repo" -ForegroundColor White


        Set-ShToolsConfig -ConfigPath $ConfigPath -Section github -Values @{
            owner = $owner
            repo = $repo
            projectNumber = $projectNumber
        }
    }

    function Update-DotnetSection {
        param(
            [string]$ConfigPath,
            [object]$CurrentConfig,
            [string]$RootDirectory
        )

        $currentDotnet = if ($CurrentConfig -and $CurrentConfig.PSObject.Properties.Name -contains "dotnet") {
            $CurrentConfig.dotnet
        } else {
            [PSCustomObject]@{}
        }

        $projectPath = $currentDotnet.projectPath
        if (Read-YesNo -Title "Select main .NET project?" -DefaultYes $true) {
            try {
                $projectPath = Select-DotnetProject -SearchRoot $RootDirectory -Prompt "Select main .NET project"
            } catch {
                Write-Host "Error selecting project: $_" -ForegroundColor Red
            }
        }

        $testProjectPath = $currentDotnet.testProjectPath
        if (Read-YesNo -Title "Select test .NET project(s)?" -DefaultYes $true) {
            try {
                $testProjectPath = Select-DotnetProjects -SearchRoot $RootDirectory -Prompt "Select test .NET project(s)"
            } catch {
                Write-Host "Error selecting test projects: $_" -ForegroundColor Red
            }
        }

        Set-ShToolsConfig -ConfigPath $ConfigPath -Section dotnet -Values @{
            projectPath = $projectPath
            testProjectPath = @($testProjectPath)
            searchRoot = $RootDirectory
        }
    }

    function Update-LocalDbSection {
        param(
            [string]$ConfigPath,
            [object]$CurrentConfig,
            [string]$RootDirectory
        )

        $currentDotnet = if ($CurrentConfig -and $CurrentConfig.PSObject.Properties.Name -contains "dotnet") {
            $CurrentConfig.dotnet
        } else {
            [PSCustomObject]@{}
        }

        $currentLocalDb = if ($CurrentConfig -and $CurrentConfig.PSObject.Properties.Name -contains "localdb") {
            $CurrentConfig.localdb
        } else {
            [PSCustomObject]@{}
        }

        $menuOptions = @(
            "Use main .NET project",
            "Select LocalDb project",
            "Skip"
        )

        $choice = Show-MenuWithTitle -Title "LocalDb project selection" -Options $menuOptions
        if (-not $choice -or $choice -eq "Skip") {
            return
        }

        $projectPath = switch ($choice) {
            "Use main .NET project" { $currentDotnet.projectPath }
            "Select LocalDb project" { 
                try {
                    Select-DotnetProject -SearchRoot $RootDirectory -Prompt "Select LocalDb project"
                } catch {
                    Write-Host "Error selecting project: $_" -ForegroundColor Red
                    $null
                }
            }
            default { $currentLocalDb.projectPath }
        }

        if (-not $projectPath) {
            Write-Host "No LocalDb project selected." -ForegroundColor Yellow
            return
        }

        Set-ShToolsConfig -ConfigPath $ConfigPath -Section localdb -Values @{
            projectPath = $projectPath
        }
    }