param (
    [string]$ProjectPath,
    [string]$SolutionPath,
    [string]$TestProjectName,
    [string]$TestProjectDirectory,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\ShTools.Core\ShTools.Core.psd1') -Force

function Resolve-SolutionPath {
    param(
        [string]$PathHint,
        [string]$SearchRoot
    )

    if ($PathHint) {
        if (-not (Test-Path $PathHint -PathType Leaf)) {
            throw "SolutionPath '$PathHint' does not exist or is not a file."
        }
        return (Resolve-Path $PathHint).Path
    }

    $solutions = Get-ChildItem -Path $SearchRoot -Filter '*.sln' -File
    if ($solutions.Count -eq 0) {
        throw "No .sln files found under '$SearchRoot'. Specify -SolutionPath."
    }

    if ($solutions.Count -eq 1) {
        return $solutions[0].FullName
    }

    if (-not (Get-Module -ListAvailable PSMenu)) {
        throw 'Multiple .sln files found. Install PSMenu or specify -SolutionPath.'
    }

    Import-Module PSMenu -ErrorAction Stop
    $selection = $solutions.FullName | Show-Menu -Title 'Select solution'
    if (-not $selection) {
        throw 'No solution selected.'
    }

    return $selection
}

function Invoke-DotnetCommand {
    param(
        [string[]]$Arguments
    )

    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet command failed: dotnet $($Arguments -join ' ')"
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Select-DotnetProject -Prompt 'Select project to test'
}

$ProjectPath = (Resolve-Path $ProjectPath).Path
$projectName = Get-ProjectNameFromPath -Path $ProjectPath

$searchRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$SolutionPath = Resolve-SolutionPath -PathHint $SolutionPath -SearchRoot $searchRoot
$solutionDirectory = Split-Path -Path $SolutionPath -Parent

if ([string]::IsNullOrWhiteSpace($TestProjectName)) {
    $TestProjectName = "$projectName.Tests"
}

if ([string]::IsNullOrWhiteSpace($TestProjectDirectory)) {
    $TestProjectDirectory = Join-Path $solutionDirectory (Join-Path 'Tests' $TestProjectName)
}

$testProjectPath = Join-Path $TestProjectDirectory "$TestProjectName.csproj"

if ((Test-Path $testProjectPath) -and (-not $Force)) {
    throw "Test project already exists: $testProjectPath. Use -Force to continue."
}

if (-not (Test-Path $TestProjectDirectory)) {
    New-Item -ItemType Directory -Path $TestProjectDirectory -Force | Out-Null
}

Write-Host "Creating MSTest project '$TestProjectName'..." -ForegroundColor Yellow
Invoke-DotnetCommand -Arguments @('new', 'mstest', '--name', $TestProjectName, '--output', $TestProjectDirectory)

Write-Host "Adding test project to solution..." -ForegroundColor Yellow
Invoke-DotnetCommand -Arguments @('sln', $SolutionPath, 'add', $testProjectPath)

Write-Host "Adding project reference to test project..." -ForegroundColor Yellow
Invoke-DotnetCommand -Arguments @('add', $testProjectPath, 'reference', $ProjectPath)

Write-Host "Test project created and wired up." -ForegroundColor Green