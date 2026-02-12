param(
    [string]$MigrationName,
    [switch]$ListMigrations,
    [switch]$Force
)

Write-Host "Entity Framework Migration Rollback Tool" -ForegroundColor Yellow

# Navigate to the project directory
Push-DotnetProjectLocation

try {
    # Check if Entity Framework tools are available
    Write-Host "Checking Entity Framework tools..." -ForegroundColor Yellow
    $efVersion = dotnet ef --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Entity Framework tools not found. Please install with: dotnet tool install --global dotnet-ef"
    } else {
        Write-Host "Entity Framework tools found: $efVersion" -ForegroundColor Green
    }

    # List migrations if requested
    if ($ListMigrations) {
        Write-Host "Available migrations:" -ForegroundColor Yellow
        dotnet ef migrations list
        exit 0
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

    # Get migration name if not provided
    if ([string]::IsNullOrWhiteSpace($MigrationName)) {
        Write-Host ""
        Write-Host "Available options:" -ForegroundColor Yellow
        Write-Host "• Enter migration name to rollback TO that migration" -ForegroundColor Gray
        Write-Host "• Enter '0' to rollback ALL migrations (empty database)" -ForegroundColor Gray
        Write-Host "• Press Enter to cancel" -ForegroundColor Gray
        Write-Host ""
        
        $MigrationName = Read-Host "Enter target migration name (or '0' for complete rollback)"
        
        if ([string]::IsNullOrWhiteSpace($MigrationName)) {
            Write-Host "Rollback cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Confirmation for rollback
    if (-not $Force) {
        Write-Host ""
        if ($MigrationName -eq "0") {
            Write-Host "WARNING: This will rollback ALL migrations and remove all tables!" -ForegroundColor Red
        } else {
            Write-Host "WARNING: This will rollback to migration '$MigrationName' and may lose data!" -ForegroundColor Red
        }
        Write-Host "This action may result in data loss." -ForegroundColor Red
        Write-Host ""
        
        $response = Read-Host "Are you sure you want to proceed? (yes/no)"
        if ($response -ne "yes" -and $response -ne "y") {
            Write-Host "Rollback cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build the project first
    Write-Host "Building project..." -ForegroundColor Yellow
    dotnet build --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Please fix compilation errors before rolling back migrations." -ForegroundColor Red
        dotnet build
        exit 1
    }

    # Perform rollback
    if ($MigrationName -eq "0") {
        Write-Host "Rolling back ALL migrations..." -ForegroundColor Red
        dotnet ef database update 0
    } else {
        Write-Host "Rolling back to migration '$MigrationName'..." -ForegroundColor Yellow
        dotnet ef database update $MigrationName
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Rollback completed successfully!" -ForegroundColor Green
        
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
        
    } else {
        Write-Host "Failed to rollback migrations" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host "Migration rollback complete!" -ForegroundColor Green