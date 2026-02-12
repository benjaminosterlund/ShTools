function Get-ProjectFileName {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    Split-Path $ProjectPath -Leaf
}

function Get-ProjectNameFromPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    [System.IO.Path]::GetFileNameWithoutExtension($Path)
}

function Push-DotnetProjectLocation {
    <#
    .SYNOPSIS
    Pushes the current location to the directory containing the selected .NET project.
    
    .DESCRIPTION
    Gets the .NET project path and navigates to its containing directory.
    Use Pop-Location to return to the previous location.
    
    .PARAMETER ProjectPath
    Optional path to a specific project file. If not provided, prompts to select a project.
    
    .EXAMPLE
    Push-DotnetProjectLocation
    # Prompts for project selection and navigates to its directory
    
    .EXAMPLE
    Push-DotnetProjectLocation -ProjectPath "C:\MyApp\MyApp.csproj"
    # Navigates to C:\MyApp
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectPath
    )
    
    # Get project path if not provided
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectPath = Get-DotnetProjectPath
    }
    
    # Extract directory and navigate
    $projectDirectory = Split-Path -Path $ProjectPath -Parent
    Push-Location $projectDirectory
    
    Write-Verbose "Navigated to project directory: $projectDirectory"
}