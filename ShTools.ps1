param(
    [switch]$Configure,  # Configure shtools.config.json
    [switch]$SkipSelfUpdate,  # Skip self-update check
    [string]$LocalSourceDir = $null  # Optional local source directory for development
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSCommandPath


$PsScriptFileName = Split-Path -Path $ScriptPath -Leaf

$toolingDirectoryName = "ShTools"    
$shToolsRepoName = "ShTools"

$repoOwner = "benjaminosterlund"
$ScriptsRepoUrl = "https://raw.githubusercontent.com/$repoOwner/$shToolsRepoName/main/$toolingDirectoryName"  # Base URL for scripts folder
$ScriptUrl = "https://raw.githubusercontent.com/$repoOwner/$shToolsRepoName/refs/heads/main/ShTools.ps1"  # URL to download script updates





#region Banner
function Show-ShToolsBanner {
    [CmdletBinding()]
    param(
        [string]$Version = "1.0.0",
        [string]$ToolName = "ShTools",
        [string]$Subtitle = "Project Architecture Tooling",
        [string]$Author = "Benjamin Österlund",
        [string]$Repo = "github.com/benjaminosterlund/ShTools",
        [switch]$NoColor
    )

    $width = 54

    function Format-Line {
        param([string]$Text)
        $contentWidth = $width - 4
        $padded = $Text.PadRight($contentWidth)
        return "│  $padded  │"
    }

    $top    = "┌" + ("─" * ($width - 2)) + "┐"
    $bottom = "└" + ("─" * ($width - 2)) + "┘"

    $lines = @(
        $top
        (Format-Line $ToolName)
        (Format-Line $Subtitle)
        (Format-Line "")
        (Format-Line "Version : $Version")
        (Format-Line "Author  : $Author")
        (Format-Line "Repo    : $Repo")
        $bottom
    )

    if (-not $NoColor -and $PSStyle) {
        $accent = $PSStyle.Foreground.BrightCyan
        $reset  = $PSStyle.Reset
        $lines = $lines | ForEach-Object {
            if ($_ -match "ShTools") {
                $_ -replace $ToolName, "$accent$ToolName$reset"
            }
            else { $_ }
        }
    }

    $lines -join "`n"
}
#endregion

#region Self-Update Functions
function Test-SelfUpdate{
    param(
        [switch]$SkipSelfUpdate
    )

    if ($SkipSelfUpdate) {
        Write-Host "Skipping self-update check as per parameter." -ForegroundColor Yellow
        return $null
    }

    if (-not (Test-ProductionEnvironment)) {
        Write-Host "Self-update skipped in development." -ForegroundColor Yellow
        return $null
    }
        $updateFile = Test-SelfUpdateAvailable -Url:$ScriptUrl -Path:$ScriptPath
        if ($updateFile) {
            Update-SelfScriptAndRestart -TempFile:$updateFile -Path:$ScriptPath
        } 
}
function Test-SelfUpdateAvailable {
    param(
        [string]$Url,
        $Path
        )
    


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
function Update-SelfScriptAndRestart {
    param(
        [string]$TempFile,
        [string]$Path
        )
    
    try {
        Write-Host "Updating script..." -ForegroundColor Yellow
        
        # Backup current version
        Write-Host "Creating backup of current script at $Path.backup..." -ForegroundColor DarkGray
        $backupPath = "$Path.backup"
        Copy-Item -Path $Path -Destination $backupPath -Force
        
        # Replace current script with new version
        Copy-Item -Path $TempFile -Destination $Path -Force
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
        
        & $Path @args -SkipSelfUpdate
        exit
    }
    catch {
        Write-Error "Failed to update script: $_"
        # Restore backup if update failed
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $Path -Force
            Write-Host "Restored backup version." -ForegroundColor Yellow
        }
        throw
    }
}

#endregion

#region Download Functions

function Update-AllToolingScripts {
    param(
        [string]$ToolingDirName = "ShTools",
        [string]$RepoOwner = "benjaminosterlund",
        [string]$RepoName = "ShTools",
        [string]$SourceFolderDirName = "Src",
        [string]$LocalSource = $null
    )
    if ($LocalSource) {
        Write-Host "Using local source directory for scripts: $LocalSource" -ForegroundColor Yellow
        $scriptInfos = Get-ScriptInfosFromLocalSource -LocalSourceRepoDir:$LocalSource
    } else {
        Write-Host "Using GitHub repository as source for scripts." -ForegroundColor Yellow
        $scriptInfos = Get-ScriptInfosFromGithub -RepoOwner:$RepoOwner -RepoName:$RepoName -SourceFolderDirName:$SourceFolderDirName -LocalSource:$LocalSource
    }

    Install-ScriptInfos -ScriptInfos:$scriptInfos -ToolingDirName:$ToolingDirName
}

function Install-ScriptInfos{
    param(
        [array]$ScriptInfos,
        [string]$ToolingDirName
    )

     if ($ScriptInfos.Count -eq 0) {
        Write-Host "No scripts available to update or install." -ForegroundColor Yellow
        return
    }

    # Clear existing scripts
    Write-Host "Clearing existing scripts in $ToolingDirName..." -ForegroundColor Yellow
    Remove-Item -Path (Join-Path $PsScriptRoot $ToolingDirName) -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Updating/installing $($ScriptInfos.Count) script(s)..." -ForegroundColor Cyan
    
    $successCount = 0
    $failCount = 0
    
    foreach ($scriptInfo in $ScriptInfos) {
        $localRelativePath = $scriptInfo.path -Replace '^Src/', "$ToolingDirName/"
        $localFullPath = Join-Path $PsScriptRoot $localRelativePath
        $localDir = Split-Path -Path $localFullPath -Parent
        if (-not (Test-Path $localDir)) {
            New-Item -Path $localDir -ItemType Directory -Force | Out-Null
        }

        if ($scriptInfo.PSObject.Properties.Name -contains "local_full_path") {
            $result = Install-OrUpdateScript -LocalPath:$scriptInfo.local_full_path -FileName:$scriptInfo.name -DestinationFolder:$localDir
        } else {
            $result = Install-OrUpdateScript -Url:$scriptInfo.download_url -FileName:$scriptInfo.name -DestinationFolder:$localDir
        }

        if ($result) {
            $successCount++
        }
        else {
            $failCount++
        }
    }
    
    Write-Host "`nUpdate/Install Summary:" -ForegroundColor Cyan
    Write-Host "  Files updated/installed: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
}

function Get-GitHubApiUrl {
    param(
        [string]$RepoOwner,
        [string]$RepoName,
        [string]$FolderPath
    )
    return "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$FolderPath"
}

function Get-ScriptInfosFromLocalSource {
    param(
        [string]$LocalSourceRepoDir = $null
    )
    $allScripts = @()
        # Get file info from local directory recursively
        $localSourceRoot = Join-Path $LocalSourceRepoDir $SourceFolderDirName
        if (-not (Test-Path $localSourceRoot)) {
            Write-Warning "Local source directory '$localSourceRoot' does not exist."
            return @()
        }
        $files = Get-ChildItem -Path $localSourceRoot -Recurse -File
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($LocalSourceRepoDir.Length).TrimStart('\','/')
            $allScripts += [PSCustomObject]@{
                type = "file"
                name = $file.Name
                path = $relativePath
                local_full_path = $file.FullName
            }
        }
    return $allScripts
}

function Test-GhCliAvailable {
    param()
    return Get-Command gh -ErrorAction SilentlyContinue
}
function Get-ScriptInfosFromGithub {
    param(
        [string]$RepoOwner = "benjaminosterlund",
        [string]$RepoName = "ShTools",
        [string]$SourceFolderDirName = "Src"
    )

    $allScripts = @()
        try {

            if (Test-GhCliAvailable) {
                Write-Host "Using gh CLI to fetch script list." -ForegroundColor Gray


                $response = gh api repos/$RepoOwner/$RepoName/contents/$SourceFolderDirName | ConvertFrom-Json

            } else {
                Write-Host "gh CLI not found, falling back to REST API." -ForegroundColor Yellow
        
                $apiUrl = Get-GitHubApiUrl -RepoOwner $RepoOwner -RepoName $RepoName -FolderPath $SourceFolderDirName
                Write-Host "Fetching script list from: $apiUrl" -ForegroundColor Cyan
                $headers = @{
                    'Accept' = 'application/vnd.github+json'
                    'User-Agent' = "PowerShell-$RepoName"
                }
                $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
            }

     

            foreach ($item in $response) {
                if ($item.type -eq "file") {
                    $allScripts += $item
                } elseif ($item.type -eq "dir") {
                    $subfolder = $item.path
                    $allScripts += Get-ScriptInfosFromGithub -RepoOwner $RepoOwner -RepoName $RepoName -SourceFolderDirName $subfolder
                }
            }
            return $allScripts
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                Write-Warning "The folder '$SourceFolderDirName' does not exist in the repository $RepoOwner/$RepoName"
                Write-Host "Please verify the folder exists at: $apiUrl" -ForegroundColor Yellow
            }
            else {
                Write-Warning "Failed to get script list from GitHub: $_"
                throw
            }
            return @()
        }
}

function Download-Script {
    param(
        [string]$Url,
        [string]$DestinationPath
    )
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing
        return $true
    }
    catch {
        Write-Warning "  ✗ Failed to download from $Url`: $_"
        return $false
    }
}

function Install-Script {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    
    try {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        return $true
    }
    catch {
        Write-Warning "  ✗ Failed to install script to $DestinationPath`: $_"
        return $false
    }
}

function Install-OrUpdateScript {
    param(
        [string]$Url,
        [string]$LocalPath,
        [string]$FileName,
        [string]$DestinationFolder
    )
    
    try {
        # Write-Host "  Installing/updating: $FileName" -ForegroundColor Gray
        
        # Ensure destination folder exists
        if (-not (Test-Path $DestinationFolder)) {
            New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
        }
        
        $destinationPath = Join-Path $DestinationFolder $FileName
        
        # Copy from local path or download from URL
        if ($LocalPath) {
            $result = Install-Script -SourcePath $LocalPath -DestinationPath $destinationPath
        } else {
            $result = Download-Script -Url $Url -DestinationPath $destinationPath
        }
        
        if ($result) {
            Write-Host "  ✓ Installed/Updated: $FileName" -ForegroundColor Green
        }
        return $result
    }
    catch {
        Write-Warning "  ✗ Failed to install/update $FileName`: $_"
        return $false
    }
}



#endregion

#region Configuration Functions

function Import-ShToolsCoreModule {
    param(
        [string]$ScriptRoot,
        [string]$ToolingDirectoryName
    )
    if (Test-ProductionEnvironment) {
        Write-Host "Running in Production environment." -ForegroundColor Gray
        Import-Module (Join-Path $ScriptRoot $ToolingDirectoryName 'ShTools.Core\ShTools.Core.psd1') -Force
    }
    else {
        Write-Host "Running in Development environment." -ForegroundColor Gray
        Import-Module (Join-Path $ScriptRoot 'Src\ShTools.Core\ShTools.Core.psd1') -Force
    }
}
    
#endregion

#region Helper Functions
function Test-DevelopmentEnvironment {
    param()
    $parentFolder = Split-Path -Path $ScriptPath -Parent | Split-Path -Leaf
    return $parentFolder -eq $shToolsRepoName
}

function Test-ProductionEnvironment {
    param()
    return -not (Test-DevelopmentEnvironment)
}



function Test-ToolingDirectoryExists {
    param(
        [string]$Dir
    )
    if (Test-Path $Dir) {
        Write-Host "✓ Scripts/tools directory exists: $Dir" -ForegroundColor Gray
        return
    }
        
    Write-Host "Creating local tooling directory: $Dir" -ForegroundColor Cyan
    New-Item -Path $Dir -ItemType Directory -Force | Out-Null
    Write-Host "✓ Directory created" -ForegroundColor Green
}

function Use-GitIgnoreForScriptsFolder {
    param(
        [string]$ToolingDirName
    )
    $gitignorePath = ".gitignore"
    $pattern = "$ToolingDirName/*"

    if (Test-Path $gitignorePath) {
        $content = Get-Content -Path $gitignorePath -Raw
        $hasEntry = $content -match [regex]::Escape($pattern)
    }
    else {
        $hasEntry = $false
    }

    if (-not $hasEntry) {
        Write-Host "`nThe '$ToolingDirName' folder contains downloaded scripts that should not be committed." -ForegroundColor Yellow
        $response = Read-Host "Add '$pattern' to .gitignore? (Y/n)"

        if ($response -eq '' -or $response -match '^[Yy]') {
            if (-not (Test-Path $gitignorePath)) {
                New-Item -Path $gitignorePath -ItemType File -Force | Out-Null
            }

            Add-Content -Path $gitignorePath -Value "`n# $ToolingDirName - Downloaded scripts`n$pattern"
            Write-Host "✓ Added to .gitignore" -ForegroundColor Green
        }
        else {
            Write-Host "Skipped .gitignore update" -ForegroundColor Gray
        }
    }
    Write-Host ""
}



    
#endregion

## Main Execution Flow
# Write-Host "=== ShTools Script Manager ===" -ForegroundColor Cyan
# Write-Host ""

Show-ShToolsBanner

if(-Not $Configure) {
    Write-Host "Starting installation process..." -ForegroundColor Cyan

    # Main execution with rollback on error
    $backupPath = "$ScriptPath.backup"
    $mainSucceeded = $false
    $rollbackAttempted = $false
    try {
        # Step: Self-update, ensure latest version
        Test-SelfUpdate -SkipSelfUpdate:$SkipSelfUpdate

        # Step: Ensure local tooling folder exists
        Test-ToolingDirectoryExists -Dir:(Join-Path $PSScriptRoot $toolingDirectoryName)

        # Step: Check and update .gitignore if needed
        Use-GitIgnoreForScriptsFolder -ToolingDirName:$toolingDirectoryName

        if (Get-Command gh -ErrorAction SilentlyContinue) {
            # Write-Host "gh.exe is installed" -ForegroundColor Green
        } else {
            Write-Host "It is recommended to install GitHub CLI (gh) for full functionality." -ForegroundColor Yellow
            Write-Host "Install via winget: winget install --id GitHub.cli -e" -ForegroundColor Yellow
            Write-Host "Or download from: https://cli.github.com/" -ForegroundColor Yellow
        }


        # Step: Update or install scripts
        Update-AllToolingScripts -ToolingDirName:$toolingDirectoryName -RepoOwner:$repoOwner -RepoName:$shToolsRepoName -LocalSource:$LocalSourceDir





        $mainSucceeded = $true
    }
    catch {
        Write-Error "An error occurred: $_"
        # Attempt rollback if backup exists
        if (Test-Path $backupPath) {
            try {
                Copy-Item -Path $backupPath -Destination $ScriptPath -Force
                Write-Host "Restored script from backup due to error." -ForegroundColor Yellow
                $rollbackAttempted = $true
            }
            catch {
                Write-Error "Failed to restore script from backup: $_"
            }
        }
        throw
    }
    finally {
        # Remove backup if everything succeeded, or after rollback attempt on failure
        if ((Test-Path $backupPath) -and ($mainSucceeded -or $rollbackAttempted)) {
            Remove-Item $backupPath -Force
        }
        # Write-Host "Installation completed." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host "  ✔ Installation completed successfully" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "To configure this project, run:" -ForegroundColor Yellow
    Write-Host "    .\shtools.ps1 -Configure" -ForegroundColor Cyan
    Write-Host ""

}



if($Configure) {

    Write-Host "Starting configuration process..." -ForegroundColor Cyan

    # Step: Configure shtools.config.json in root
    Import-ShToolsCoreModule -ScriptRoot $PSScriptRoot -ToolingDirectoryName $toolingDirectoryName
    Set-Configuration -RootDirectory $PSScriptRoot -ToolingDirectory $toolingDirectoryName

}

## End of Script