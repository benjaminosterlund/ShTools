param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '..\..\Ensure-ShToolsCore.ps1') -ScriptRoot $PSScriptRoot


$projectPath = $ProjectPath


if (-not (Test-DotnetUserSecretsInitialized -ProjectPath $projectPath)) {
    throw "User secrets are not initialized for: $projectPath"
}

$defaultDatabaseName = $ProjectPath -replace '.*\\(.*?)\.csproj','$1' -replace 'Api$','db'

    Write-Host "Configure your MariaDB connection string:" -ForegroundColor Cyan
    $server = Read-Host "Server (default: 127.0.0.1)"
    if (-not $server) { $server = "127.0.0.1" }
    $port = Read-Host "Port (default: 3306)"
    if (-not $port) { $port = "3306" }
    $database = Read-Host "Database name (default: $defaultDatabaseName)"
    if (-not $database) { $database = $defaultDatabaseName }
    $user = Read-Host "Username (default: root)"
    if (-not $user) { $user = "root" }
    $password = Read-Host "Password (default: admin)"
    if (-not $password) { $password = "admin" }

    $ConnectionString = "Server=$server;Port=$port;Database=$database;User Id=$user;Password=$password;Connection Timeout=20;"
    $TestConnectionString = "Server=$server;Port=$port;Database=${database}Test;User Id=$user;Password=$password;Connection Timeout=20;"

# Set the connection string in user-secrets
Write-Host "Setting connection string in user-secrets..." -ForegroundColor Yellow
& dotnet user-secrets set "ConnectionStrings:DefaultConnection" "$ConnectionString" --project $projectPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "Main connection string set successfully." -ForegroundColor Green
} else {
    Write-Host "Failed to set main connection string." -ForegroundColor Red
    exit 1
}

# Set the test connection string in user-secrets
Write-Host "Setting test connection string in user-secrets..." -ForegroundColor Yellow
& dotnet user-secrets set "ConnectionStrings:TestConnection" "$TestConnectionString" --project $projectPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "Test connection string set successfully." -ForegroundColor Green
} else {
    Write-Host "Failed to set test connection string." -ForegroundColor Red
    exit 1
}

Write-Host "`nDatabases to create:" -ForegroundColor Cyan
Write-Host "Main database: $database" -ForegroundColor White
Write-Host "Test database: ${database}Test" -ForegroundColor White
