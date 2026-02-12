param(
    [string]$MigrationName
)

Write-Host "Entity Framework Migration Tool" -ForegroundColor Green

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

    # Get migration name if not provided
    if ([string]::IsNullOrWhiteSpace($MigrationName)) {
        do {
            $MigrationName = Read-Host "Enter migration name (e.g., 'InitialCreate', 'AddUserTable', 'UpdateRecipeModel')"
            if ([string]::IsNullOrWhiteSpace($MigrationName)) {
                Write-Host "Migration name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($MigrationName))
    }

    # Validate migration name (remove spaces and special characters)
    $CleanMigrationName = $MigrationName -replace '[^a-zA-Z0-9_]', ''
    if ($CleanMigrationName -ne $MigrationName) {
        Write-Host "Migration name cleaned: '$MigrationName' -> '$CleanMigrationName'" -ForegroundColor Yellow
        $MigrationName = $CleanMigrationName
    }

    # Check if migrations folder exists and show existing migrations
    $MigrationsPath = "./Migrations"
    if (Test-Path $MigrationsPath) {
        $existingMigrations = Get-ChildItem $MigrationsPath -Filter "*_*.cs" | ForEach-Object { 
            $_.Name -replace '^\d+_(.+)\.cs$', '$1' 
        }
        if ($existingMigrations.Count -gt 0) {
            Write-Host "Existing migrations:" -ForegroundColor Yellow
            $existingMigrations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        }
    }

    # Build the project first to ensure model is valid
    Write-Host "Building project to validate model changes..." -ForegroundColor Yellow
    dotnet build --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Please fix compilation errors before creating migration." -ForegroundColor Red
        dotnet build
        exit 1
    }

    # Create the migration
    Write-Host "Creating migration '$MigrationName'..." -ForegroundColor Yellow
    dotnet ef migrations add $MigrationName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Migration '$MigrationName' created successfully!" -ForegroundColor Green
        
        # Show the generated migration files
        $migrationFiles = Get-ChildItem $MigrationsPath -Filter "*$MigrationName*" | Sort-Object Name
        if ($migrationFiles.Count -gt 0) {
            Write-Host "Generated files:" -ForegroundColor Yellow
            $migrationFiles | ForEach-Object { 
                Write-Host "  - $($_.Name)" -ForegroundColor Gray 
            }
        }
        
        # Ask if user wants to update the database
        $updateDb = Read-Host "Do you want to apply this migration to the database now? (y/N)"
        if ($updateDb -eq 'y' -or $updateDb -eq 'Y') {
            Write-Host "Updating database..." -ForegroundColor Yellow
            dotnet ef database update
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Database updated successfully!" -ForegroundColor Green
            } else {
                Write-Host "Failed to update database. You can run 'dotnet ef database update' manually later." -ForegroundColor Red
            }
        } else {
            Write-Host "Migration created but not applied. Run 'dotnet ef database update' to apply it." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Failed to create migration '$MigrationName'" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host "Migration process complete!" -ForegroundColor Green