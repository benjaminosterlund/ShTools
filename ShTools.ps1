param(
  
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSCommandPath


$UpdateUrl = "https://raw.githubusercontent.com/benjaminosterlund/ShTools/refs/heads/main/ShTools.ps1"  # URL to download script updates
$ScriptsRepoUrl = "https://raw.githubusercontent.com/benjaminosterlund/ShTools/main/ShTools"  # Base URL for scripts folder
$LocalScriptsFolder = "ShTools"      
$shToolsRepoName = "ShTools"

#region Self-Update Functions

function Test-UpdateAvailable {
    param([string]$Url)
    
    try {
        Write-Host "Checking for updates from: $Url" -ForegroundColor Cyan
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # Download the latest version
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing
        
        # Compare file hashes
        $currentHash = (Get-FileHash -Path $ScriptPath -Algorithm SHA256).Hash
        $newHash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash
        
        if ($currentHash -ne $newHash) {
            Write-Host "Update available!" -ForegroundColor Green
            return $tempFile
        }
        else {
            Write-Host "Already running latest version." -ForegroundColor Green
            Remove-Item -Path $tempFile -Force
            return $null
        }
    }
    catch {
        Write-Warning "Failed to check for updates: $_"
        return $null
    }
}

function Configure-ShtoolsConfigIfNotExists {
    param(
        [string]$ScriptsFolder
    )

    $configPath = Join-Path $PsScriptRoot "shtools.config.json"

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
            scriptsFolder   = $ScriptsFolder
            autoUpdate      = $true
            projectPath     = $projectPath
            testProjectPath = @($testProjectPath)
        }



        $config | ConvertTo-Json | Set-Content -Path:$configPath
        Write-Host "✓ Configuration file created: $configPath" -ForegroundColor Green
    }
}

function Update-SelfScriptAndRestart {
    param([string]$TempFile)
    
    try {
        Write-Host "Updating script..." -ForegroundColor Yellow
        
        # Backup current version
        $backupPath = "$ScriptPath.backup"
        Copy-Item -Path $ScriptPath -Destination $backupPath -Force
        
        # Replace current script with new version
        Copy-Item -Path $TempFile -Destination $ScriptPath -Force
        Remove-Item -Path $TempFile -Force
        
        Write-Host "Script updated successfully!" -ForegroundColor Green
        Write-Host "Restarting script..." -ForegroundColor Cyan
        
        # Restart the script with original parameters
        $args = $MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [switch]) {
                if ($_.Value) { "-$($_.Key)" }
            }
            else {
                "-$($_.Key)", $_.Value
            }
        }
        
        & $ScriptPath @args -SkipUpdate
        exit
    }
    catch {
        Write-Error "Failed to update script: $_"
        # Restore backup if update failed
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $ScriptPath -Force
            Write-Host "Restored backup version." -ForegroundColor Yellow
        }
        throw
    }
}

#endregion

#region Download Functions

function Get-GitHubScriptsList {
    param(
        [string]$RepoOwner = "benjaminosterlund",
        [string]$RepoName = "ShTools",
        [string]$FolderPath = "Src"
    )
    $allScripts = @()
    try {
        $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$FolderPath"
        Write-Host "Fetching script list from: $apiUrl" -ForegroundColor Cyan
        $headers = @{
            'Accept' = 'application/vnd.github+json'
            'User-Agent' = "PowerShell-$RepoName"
        }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
        foreach ($item in $response) {
            if ($item.type -eq "file") {
                $allScripts += $item
            } elseif ($item.type -eq "dir") {
                $subfolder = $item.path
                $allScripts += Get-GitHubScriptsList -RepoOwner $RepoOwner -RepoName $RepoName -FolderPath $subfolder
            }
        }
        return $allScripts
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Warning "The folder '$FolderPath' does not exist in the repository $RepoOwner/$RepoName"
            Write-Host "Please verify the folder exists at: $apiUrl" -ForegroundColor Yellow
        }
        else {
            Write-Warning "Failed to get script list from GitHub: $_"
        }
        return @()
    }
}

function Download-Script {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$DestinationFolder
    )
    
    try {
        Write-Host "  Downloading: $FileName" -ForegroundColor Gray
        
        # Ensure destination folder exists
        if (-not (Test-Path $DestinationFolder)) {
            New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
        }
        
        $destinationPath = Join-Path $DestinationFolder $FileName
        
        # Download the script
        Invoke-WebRequest -Uri $Url -OutFile $destinationPath -UseBasicParsing
        
        Write-Host "  ✓ Downloaded: $FileName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "  ✗ Failed to download $FileName`: $_"
        return $false
    }
}

function Download-AllScripts {
    param(
        [string]$LocalFolderName = "ShTools"
    )
    
    $scripts = Get-GitHubScriptsList
    
    if ($scripts.Count -eq 0) {
        Write-Host "No scripts available to download." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nDownloading scripts..." -ForegroundColor Cyan
    
    $successCount = 0
    $failCount = 0
    
    foreach ($script in $scripts) {
        $localRelativePath = $script.path -Replace '^Src/', "$LocalFolderName/" 
        $localFullPath = Join-Path $PsScriptRoot $localRelativePath
        $localDir = Split-Path -Path $localFullPath -Parent
        if (-not (Test-Path $localDir)) {
            New-Item -Path $localDir -ItemType Directory -Force | Out-Null
        }


        $result = Download-Script -Url $script.download_url -FileName $script.name -DestinationFolder $localDir

        
        if ($result) {
            $successCount++
        }
        else {
            $failCount++
        }
    }
    
    Write-Host "`nDownload Summary:" -ForegroundColor Cyan
    Write-Host "  Files downloaded: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
}


function IsDevelopmentEnvironment {
    param()
    $parentFolder = Split-Path -Path $ScriptPath -Parent | Split-Path -Leaf
    return $parentFolder -eq $shToolsRepoName
}

function IsProductionEnvironment {
    param()
    return -not (IsDevelopmentEnvironment)
}
#endregion





## Main Execution Flow
    Write-Host "=== ShTools Script Manager ===" -ForegroundColor Cyan
    Write-Host ""


    # Step: Self-update (Always at end to avoid interruptions)
    # Dynamically detect if the parent folder is 'ShTools'


    $parentFolder = Split-Path -Path $ScriptPath -Parent | Split-Path -Leaf
    if (IsProductionEnvironment) {
        $updateFile = Test-UpdateAvailable -Url $UpdateUrl
        if ($updateFile) {
            Update-SelfScriptAndRestart -TempFile $updateFile
        }
        
    } else {
        Write-Host "Self-update skipped in development." -ForegroundColor Yellow
    }

    # Step: Setup local scripts folder
    if (-not (Test-Path $LocalScriptsFolder)) {
        Write-Host "Creating local scripts folder: $LocalScriptsFolder" -ForegroundColor Cyan
        New-Item -Path $LocalScriptsFolder -ItemType Directory -Force | Out-Null
        Write-Host "✓ Folder created" -ForegroundColor Green
    }
    else {
        Write-Host "✓ Scripts/tools folder exists: $LocalScriptsFolder" -ForegroundColor Gray
    }


    # Step: Check and update .gitignore if needed
    $gitignorePath = ".gitignore"
    $pattern = "$LocalScriptsFolder/*"
    
    if (Test-Path $gitignorePath) {
        $content = Get-Content -Path $gitignorePath -Raw
        $hasEntry = $content -match [regex]::Escape($pattern)
    }
    else {
        $hasEntry = $false
    }
    
    if (-not $hasEntry) {
        Write-Host "`nThe '$LocalScriptsFolder' folder contains downloaded scripts that should not be committed." -ForegroundColor Yellow
        $response = Read-Host "Add '$pattern' to .gitignore? (Y/n)"
        
        if ($response -eq '' -or $response -match '^[Yy]') {
            if (-not (Test-Path $gitignorePath)) {
                New-Item -Path $gitignorePath -ItemType File -Force | Out-Null
            }
            
            Add-Content -Path $gitignorePath -Value "`n# $LocalScriptsFolder - Downloaded scripts`n$pattern"
            Write-Host "✓ Added to .gitignore" -ForegroundColor Green
        }
        else {
            Write-Host "Skipped .gitignore update" -ForegroundColor Gray
        }
    }
    Write-Host ""

    # Step 4: Download scripts
    Download-AllScripts -LocalFolderName $LocalScriptsFolder


    if (IsProductionEnvironment) {
        Write-Host "Running in Production environment." -ForegroundColor Gray
        Import-Module (Join-Path $PSScriptRoot $LocalScriptsFolder 'ShTools.Core\ShTools.Core.psd1') -Force
    } else {
        Write-Host "Running in Development environment." -ForegroundColor Gray
        Import-Module (Join-Path $PSScriptRoot '\Src\ShTools.Core\ShTools.Core.psd1') -Force
    }


    # Step: Configure shtools.config.json in root
    # Configure-ShtoolsConfigIfNotExists -ConfigPath $configPath -ScriptsFolder $LocalScriptsFolder


    # Step: Remove Backup
    $backupPath = \"$ScriptPath.backup\"
    if (Test-Path $backupPath) {
        Remove-Item $backupPath -Force
    }

    # Step: Final Message
    Write-Host "All tasks completed." -ForegroundColor Cyan

## End of Script