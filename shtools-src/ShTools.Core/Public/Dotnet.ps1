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