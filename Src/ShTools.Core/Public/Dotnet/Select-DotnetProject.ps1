
function Select-DotnetProject {
    [CmdletBinding()]
    param(
        [string]$ProjectPath,
        [string]$SearchRoot = (Join-Path $PSScriptRoot '..\..\..\'),
        [string]$Prompt = 'Select .NET project'
    )

    if ($ProjectPath) {
        if (Test-Path $ProjectPath -PathType Leaf) {
            return (Resolve-Path $ProjectPath).Path
        }
        throw "ProjectPath '$ProjectPath' does not exist or is not a file."
    }

    $candidates = Get-ChildItem -Path $SearchRoot -Filter '*.csproj' -Recurse -File

    if ($candidates.Count -eq 0) {
        throw 'No .csproj files found.'
    }

    if ($candidates.Count -eq 1) {
        return $candidates[0].FullName
    }
    
    if (-not (Get-Module -ListAvailable PSMenu)) {
        throw 'Install PSMenu or specify -ProjectPath.'
    }
    
    Import-Module PSMenu -ErrorAction Stop

    $selection = $candidates.FullName |
    Show-Menu -Title $Prompt

    if ($selection) {
        return $selection
    }

    throw 'No project selected.'
}

function Select-DotnetProjects {
    [CmdletBinding()]
    param(
        [string[]]$ProjectPath,
        [string]$SearchRoot = (Join-Path $PSScriptRoot '..\..\..\'),
         [string]$Prompt = 'Select .NET project(s)'
    )

    # Explicit path(s)
    if ($ProjectPath) {
        $resolved = foreach ($p in $ProjectPath) {
            if (-not (Test-Path $p -PathType Leaf)) {
                throw "ProjectPath '$p' does not exist or is not a file."
            }
            (Resolve-Path $p).Path
        }

        if (-not $resolved -or $resolved.Count -eq 0) {
            throw 'No project selected.'
        }

        return @($resolved)
    }

    # Discover candidates
    $candidates = @(Get-ChildItem -Path $SearchRoot -Filter '*.csproj' -Recurse -File)

    if ($candidates.Count -eq 0) {
        throw 'No .csproj files found.'
    }

    if ($candidates.Count -eq 1) {
        return @($candidates[0].FullName)
    }

    if (-not (Get-Module -ListAvailable PSMenu)) {
        throw 'Install PSMenu or specify -ProjectPath.'
    }

    Import-Module PSMenu -ErrorAction Stop

    # Multi-select if supported by your PSMenu version; otherwise you'll get single selection.
    $cmd = Get-Command Show-Menu -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'PSMenu is installed but Show-Menu was not found.' }

    if ($cmd.Parameters.ContainsKey('MultiSelect')) {
        $selection = $candidates.FullName | Show-Menu -Title $Prompt -MultiSelect
    }
    else {
        # Fallback: ask repeatedly
        $selection = @()
        while ($true) {
            $picked = $candidates.FullName | Show-Menu -Title "$Prompt (Cancel to stop)"
            if (-not $picked) { break }
            $selection += $picked
            $selection = $selection | Select-Object -Unique
        }
    }

    if ($selection -and @($selection).Count -gt 0) {
        return @($selection)
    }

    throw 'No project selected.'
}
