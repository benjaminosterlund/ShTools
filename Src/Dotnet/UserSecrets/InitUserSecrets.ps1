
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,
    [Parameter(Mandatory=$false)]
    [string[]]$TestProjectPath,
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '..\..\Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot

# Select project paths
$ProjectPath = Select-DotnetProject -ProjectPath:$ProjectPath
$projectName = Get-ProjectNameFromPath -Path:$ProjectPath
$TestProjectPath = Select-DotnetProjects -ProjectPath:$TestProjectPath

 
# Initialize main project
Write-Host "Initializing user secrets for main project..." -ForegroundColor Cyan
$mainSuccess = Initialize-ProjectUserSecrets -ProjectFile $ProjectPath -ProjectName $projectName -Reset:$Reset

if (-not $mainSuccess) {
    exit 1
}

# Initialize each test project with the same UserSecretsId as main project
$testProjectPaths = $TestProjectPath | ForEach-Object { Resolve-Path $_ }

foreach ($testProjPath in $testProjectPaths) {
    $testProjectName = Get-ProjectNameFromPath -Path:$testProjPath
    Write-Host "`nInitializing user secrets for test project: $testProjPath" -ForegroundColor Cyan
    $testSuccess = Initialize-ProjectUserSecrets -ProjectFile $testProjPath -ProjectName $testProjectName -Reset:$Reset
    if ($testSuccess) {
        # Get the UserSecretsId from the main project
        $mainCsprojContent = Get-Content $ProjectPath -Raw
        if ($mainCsprojContent -match '<UserSecretsId>([^<]+)</UserSecretsId>') {
            $userSecretsId = $matches[1]
            # Update test project to use the same UserSecretsId
            $testCsprojContent = Get-Content $testProjPath -Raw
            if ($testCsprojContent -match '<UserSecretsId>([^<]+)</UserSecretsId>') {
                # Replace existing UserSecretsId
                $testCsprojContent = $testCsprojContent -replace '<UserSecretsId>[^<]+</UserSecretsId>', "<UserSecretsId>$userSecretsId</UserSecretsId>"
            } else {
                # Add UserSecretsId to PropertyGroup
                $testCsprojContent = $testCsprojContent -replace '(<PropertyGroup[^>]*>)', "`$1`n    <UserSecretsId>$userSecretsId</UserSecretsId>"
            }
            Set-Content $testProjPath -Value $testCsprojContent -NoNewline
            Write-Host "✓ Test project configured to use the same UserSecretsId as main project." -ForegroundColor Green
        }
    }
}


Write-Host "`n✓ Done initializing user secrets for all projects." -ForegroundColor Green

return 'Done'