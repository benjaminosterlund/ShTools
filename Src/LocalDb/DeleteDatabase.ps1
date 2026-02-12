param(
    [switch]$NoConfirm
)

Write-Host "Deleting Database..." -ForegroundColor Red


try {
    # Check if we have a connection string configured
    Write-Host "Checking connection string configuration..." -ForegroundColor Yellow
    $ConnectionString = Get-LocalDbConnectionString
    
    if ([string]::IsNullOrEmpty($ConnectionString)) {
        Write-Host "No connection string found. Please run the user secrets setup first:" -ForegroundColor Red
        Write-Host "  & './ShTools/DotnetUserSecrets/SetUserSecretsDbConnectionString.ps1'" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Connection string found: $($ConnectionString.Substring(0, [Math]::Min(50, $ConnectionString.Length)))..." -ForegroundColor Green

    # Get database name using helper function
    $DatabaseName = Get-DatabaseName -ConnectionString $ConnectionString
    Write-Host "Target database: $DatabaseName" -ForegroundColor Yellow

    # Confirmation prompt unless -NoConfirm is specified
    if (-not $NoConfirm) {
        Write-Host ""
        Write-Host "WARNING: This will permanently delete the database '$DatabaseName' and all its data!" -ForegroundColor Red
        Write-Host "This action cannot be undone." -ForegroundColor Red
        Write-Host ""
        
        do {
            $response = Read-Host "Are you sure you want to delete the database '$DatabaseName'? (yes/no)"
            $response = $response.ToLower().Trim()
        } while ($response -ne "yes" -and $response -ne "no" -and $response -ne "y" -and $response -ne "n")
        
        if ($response -eq "no" -or $response -eq "n") {
            Write-Host "Database deletion cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Ensure SimplySql module is available
    Install-RequiredModule -Name SimplySql -Install

    # Connect to MySQL server (without specifying database)
    $ServerConnectionString = Get-ServerConnectionString -ConnectionString $ConnectionString
    Write-Host "Connecting to MySQL server..." -ForegroundColor Yellow
    
    Open-SqlConnection -ConnectionString $ServerConnectionString

    try {
        # Check if database exists
        if (-not (Test-DatabaseExists -DatabaseName $DatabaseName)) {
            Write-Host "Database '$DatabaseName' does not exist. Nothing to delete." -ForegroundColor Yellow
            exit 0
        }

        # Drop the database
        Write-Host "Deleting database '$DatabaseName'..." -ForegroundColor Red
        Remove-LocalDatabase -ConnectionString $ConnectionString
        Write-Host "Database '$DatabaseName' deleted successfully!" -ForegroundColor Green

    } finally {
        Close-SqlConnection
    }

} catch {
    Write-Host "Error deleting database: $_" -ForegroundColor Red
    Write-Host "Full error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Database deletion complete!" -ForegroundColor Green