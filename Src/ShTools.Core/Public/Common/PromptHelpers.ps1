function Read-YesNo {
    <#
    .SYNOPSIS
        Read user confirmation with yes/no response.
    #>
    param(
        [string]$Title,
        [bool]$DefaultYes = $true
    )
    
    $defaultText = if ($DefaultYes) { "Y/n" } else { "y/N" }
    $response = Read-Host "$Title ($defaultText)"
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    
    return ($response -match '^[Yy]')
}

function Select-YesNo {
    <#
    .SYNOPSIS
        Select yes/no confirmation using interactive menu (PSMenu if available, fallback to console input).
    .DESCRIPTION
        Provides an interactive yes/no selection using PSMenu module if available.
        Falls back to Read-YesNo if PSMenu is not available.
    .PARAMETER Title
        The prompt message to display to the user.
    .PARAMETER DefaultYes
        If $true (default), "Yes" is the default selection. If $false, "No" is the default.
    .OUTPUTS
        [bool] Returns $true for Yes, $false for No.
    .EXAMPLE
        $confirmed = Select-YesNo -Title "Do you want to continue?"
        
        Returns $true if user selects Yes, $false if No.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [bool]$DefaultYes = $true
    )
    
    Write-Host $Title
    
    # Try to use PSMenu if available
    try {
        if (Get-Command Show-Menu -ErrorAction SilentlyContinue) {
            $options = @("Yes", "No")
            
            $selection = Show-Menu -MenuItems $options 
            
            if ($null -eq $selection) {
                return $DefaultYes
            }
            
            return ($selection -eq "Yes")
        }
    }
    catch {
        Write-Verbose "PSMenu not available, falling back to console input: $_"
    }
    
    # Fallback to console-based reading
    Read-YesNo -Title $Title -DefaultYes $DefaultYes
}
