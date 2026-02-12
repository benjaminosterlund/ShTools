param(
    [string]$TargetMigration,
    [switch]$ListMigrations,
    [switch]$Force
)

Write-Host "Entity Framework Migration Application Tool" -ForegroundColor Green

# Navigate to the project directory
Push-DotnetProjectLocation

try {
    # Check if Entity Framework tools are available
    Write-Host "Checking Entity Framework tools..." -ForegroundColor Yellow
    $efVersion = dotnet ef --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Entity Framework tools not found. Installing..." -ForegroundColor Yellow
        dotnet tool install --global dotnet-ef
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Entity Framework tools"
        }
    } else {
        Write-Host "Entity Framework tools found: $efVersion" -ForegroundColor Green
    }

    # List migrations if requested
    if ($ListMigrations) {
        Write-Host "Available migrations:" -ForegroundColor Yellow
        dotnet ef migrations list
        exit 0
    }

    # Check current database status
    Write-Host "Checking current database status..." -ForegroundColor Yellow
    $dbExists = $true
    try {
        dotnet ef migrations list --no-build 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $dbExists = $false
        }
    } catch {
        $dbExists = $false
    }

    if (-not $dbExists) {
        Write-Host "Database does not exist or is not accessible." -ForegroundColor Yellow
        if (-not $Force) {
            $createDb = Read-Host "Do you want to create the database first? (Y/n)"
            if ($createDb -eq 'n' -or $createDb -eq 'N') {
                Write-Host "Migration cancelled. Database must exist to apply migrations." -ForegroundColor Red
                exit 1
            }
        }
        
        Write-Host "Creating database..." -ForegroundColor Yellow
        & "$PSScriptRoot/CreateDatabase.ps1"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create database"
        }
    }

    # Show current migration status
    Write-Host "Current migration status:" -ForegroundColor Yellow
    try {
        $appliedMigrations = dotnet ef migrations list --no-build 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host $appliedMigrations -ForegroundColor Gray
        }
    } catch {
        Write-Host "Could not retrieve migration status." -ForegroundColor Yellow
    }

    # Build the project first to ensure everything is valid
    Write-Host "Building project..." -ForegroundColor Yellow
    dotnet build --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Please fix compilation errors before applying migrations." -ForegroundColor Red
        dotnet build
        exit 1
    }

    # Apply migrations
    if ([string]::IsNullOrWhiteSpace($TargetMigration)) {
        Write-Host "Applying all pending migrations..." -ForegroundColor Yellow
        dotnet ef database update
    } else {
        Write-Host "Applying migrations up to '$TargetMigration'..." -ForegroundColor Yellow
        dotnet ef database update $TargetMigration
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Migrations applied successfully!" -ForegroundColor Green
        
        # Show updated migration status
        Write-Host "Updated migration status:" -ForegroundColor Yellow
        try {
            $updatedMigrations = dotnet ef migrations list --no-build 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host $updatedMigrations -ForegroundColor Gray
            }
        } catch {
            Write-Host "Could not retrieve updated migration status." -ForegroundColor Yellow
        }
        
        # Test database connection
        Write-Host "Testing database connection..." -ForegroundColor Yellow
        & "$PSScriptRoot/TestConnection.ps1"
        
    } else {
        Write-Host "Failed to apply migrations" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host "Migration application complete!" -ForegroundColor Green