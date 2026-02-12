param(
    [switch]$NoConfirm
)

Write-Host "Recreating Database..." -ForegroundColor Cyan

try {
    # Delete the existing database
    Write-Host "Step 1: Deleting existing database..." -ForegroundColor Yellow
    if ($NoConfirm) {
        & "$PSScriptRoot\DeleteDatabase.ps1" -NoConfirm
    } else {
        & "$PSScriptRoot\DeleteDatabase.ps1"
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete database"
    }

    Write-Host ""
    Write-Host "Step 2: Creating new database..." -ForegroundColor Yellow
    & "$PSScriptRoot\CreateDatabase.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create database"
    }

    Write-Host ""
    Write-Host "Database recreation completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Error during database recreation: $_" -ForegroundColor Red
    exit 1
}