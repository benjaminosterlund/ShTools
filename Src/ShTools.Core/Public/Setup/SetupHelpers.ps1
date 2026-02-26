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