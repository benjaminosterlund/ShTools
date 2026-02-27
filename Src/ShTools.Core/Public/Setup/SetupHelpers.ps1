function Confirm-ContinueSetup {
    <#
    .SYNOPSIS
        Confirm user wants to continue with setup wizard.
    #>
    [CmdletBinding()]
    param()
    
    if (-not (Select-YesNo -Title "Continue with setup wizard?" -DefaultYes $true)) {
        Write-Host "Setup wizard cancelled." -ForegroundColor Yellow
        return $false
    }
    
    return $true
}


function Confirm-ProceedWithSetup {
    <#
    .SYNOPSIS
        Confirm user wants to proceed with the selected setup components.
    #>
    [CmdletBinding()]
    param()
    
    if (-not (Select-YesNo -Title "Proceed with setup?" -DefaultYes $true)) {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        return $false
    }
    
    return $true
}


function Confirm-ProceedWithSettingUpComponentsDespiteError {
    <#
    .SYNOPSIS
        Confirm user wants to proceed with the selected setup components despite errors.
    #>
    [CmdletBinding()]
    param()
    
    if (-not (Select-YesNo -Title "Continue with remaining components?" -DefaultYes $true)) {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        return $false
    }
    
    return $true
}


function Show-SetupCompleteBanner {
    <#
    .SYNOPSIS
        Display setup wizard completion banner.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║            Setup Wizard Complete!                            ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}





function Show-SetupConfigurationStatus {
    <#
    .SYNOPSIS
        Display setup analysis and current configuration status.
    .PARAMETER RootDirectory
        Root directory used to resolve and evaluate configuration status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory
    )

    Write-Host ""
    Write-Host "Analyzing current setup..." -ForegroundColor Cyan

    $configStatus = Get-ConfigurationStatus -RootDirectory $RootDirectory
    Show-ConfigurationStatus -Status $configStatus
}