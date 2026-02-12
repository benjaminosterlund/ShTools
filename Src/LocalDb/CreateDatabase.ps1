param(
    [switch]$Force,
    [ValidateSet("MySQL", "MariaDB", "SqlServer")]
    [string]$DatabaseType = "MySQL"
)

Write-Host "Creating Databases (Main and Test) with $DatabaseType..." -ForegroundColor Green


try {
    # Check if we have a connection string configured
    Write-Host "Checking main database connection string configuration..." -ForegroundColor Yellow
    $ConnectionString = Get-LocalDbConnectionString
    
    if ([string]::IsNullOrEmpty($ConnectionString)) {
        Write-Host "No main connection string found. Please run the user secrets setup first:" -ForegroundColor Red
        Write-Host "  & '$PSScriptRoot/../DotnetUserSecrets/SetDbConnectionString.ps1'" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Main connection string found: $($ConnectionString.Substring(0, [Math]::Min(50, $ConnectionString.Length)))..." -ForegroundColor Green

    # Check if we have a test connection string configured
    Write-Host "Checking test database connection string configuration..." -ForegroundColor Yellow
    $TestConnectionString = & "$PSScriptRoot/../DotnetUserSecrets/GetTestDbConnectionString.ps1"
    
    if ([string]::IsNullOrEmpty($TestConnectionString)) {
        Write-Host "No test connection string found. Please run the test setup first:" -ForegroundColor Yellow
        Write-Host "  & '$PSScriptRoot/../DotnetUserSecrets/SetTestDbConnectionString.ps1'" -ForegroundColor Yellow
        Write-Host "Proceeding with main database only..." -ForegroundColor Yellow
    } else {
        Write-Host "Test connection string found: $($TestConnectionString.Substring(0, [Math]::Min(50, $TestConnectionString.Length)))..." -ForegroundColor Green
    }

    # Get database names using helper function
    $DatabaseName = Get-DatabaseName -ConnectionString $ConnectionString
    Write-Host "Target main database: $DatabaseName" -ForegroundColor Yellow
    
    $TestDatabaseName = $null
    if (-not [string]::IsNullOrEmpty($TestConnectionString)) {
        $TestDatabaseName = Get-DatabaseName -ConnectionString $TestConnectionString
        Write-Host "Target test database: $TestDatabaseName" -ForegroundColor Yellow
    }

    # Ensure SimplySql module is available
    Install-RequiredModule -Name SimplySql -Install

    # Connect 
    $ServerConnectionString = Get-ServerConnectionString -ConnectionString $ConnectionString
    Write-Host "Connecting to $DatabaseType..." -ForegroundColor Yellow
    
    Open-SqlConnection -ConnectionString $ServerConnectionString

    try {
        # Drop databases if Force is specified
        if ($Force) {
            Write-Host "Force mode: Dropping existing databases..." -ForegroundColor Yellow
            
            $dropQuery = "DROP DATABASE IF EXISTS ``$DatabaseName``;"
            Invoke-SqlQuery -Query $dropQuery
            Write-Host "Existing main database '$DatabaseName' dropped." -ForegroundColor Green
            
            if ($TestDatabaseName) {
                $dropTestQuery = "DROP DATABASE IF EXISTS ``$TestDatabaseName``;"
                Invoke-SqlQuery -Query $dropTestQuery
                Write-Host "Existing test database '$TestDatabaseName' dropped." -ForegroundColor Green
            }
        }

        # Create main database
        Write-Host "Creating main database '$DatabaseName'..." -ForegroundColor Yellow
        $createDbQuery = "CREATE DATABASE IF NOT EXISTS ``$DatabaseName`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        Invoke-SqlQuery -Query $createDbQuery
        Write-Host "Main database created successfully!" -ForegroundColor Green
        
        # Create test database if we have a test connection string
        if ($TestDatabaseName) {
            Write-Host "Creating test database '$TestDatabaseName'..." -ForegroundColor Yellow
            $createTestDbQuery = "CREATE DATABASE IF NOT EXISTS ``$TestDatabaseName`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            Invoke-SqlQuery -Query $createTestDbQuery
            Write-Host "Test database created successfully!" -ForegroundColor Green
        }

    } finally {
        Close-SqlConnection
    }
    
    # Test the connection to the new database
    Write-Host "Testing database connection..." -ForegroundColor Yellow
    & "$PSScriptRoot/TestConnection.ps1" -Database:"localdb"
    & "$PSScriptRoot/TestConnection.ps1" -Database:"testdb"


} catch {
    Write-Host "Error creating database: $_" -ForegroundColor Red
    Write-Host "Full error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Database setup complete!" -ForegroundColor Green
if ($TestDatabaseName) {
    Write-Host "Both main and test databases are ready for use." -ForegroundColor Green
} else {
    Write-Host "Main database is ready. Run SetTestDbConnectionString.ps1 and CreateDatabase.ps1 again to set up test database." -ForegroundColor Yellow
}