$connectionstring = & $PSScriptRoot/GetLocalDbConnectionString.ps1
$testconnectionstring = & $PSScriptRoot/GetTestDbConnectionString.ps1

Write-Host "`nDatabase connection strings:" -ForegroundColor Cyan
Write-Host "Main database: $connectionstring" -ForegroundColor White
Write-Host "Test database: $testconnectionstring" -ForegroundColor White