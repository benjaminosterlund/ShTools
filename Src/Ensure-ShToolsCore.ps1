if (Get-Module ShTools.Core) {
    return
}

$resolvedRoot = Resolve-Path $PSScriptRoot -ErrorAction Stop
$currentDirectory = Get-Item $resolvedRoot

while ($currentDirectory) {
    $modulePath = Join-Path $currentDirectory.FullName 'ShTools.Core\ShTools.Core.psd1'
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        return
    }

    $currentDirectory = $currentDirectory.Parent
}

throw "ShTools.Core module not found. Starting from '$ScriptRoot', no 'ShTools.Core\ShTools.Core.psd1' was found in parent directories."
