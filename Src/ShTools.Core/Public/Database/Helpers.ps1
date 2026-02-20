

function Get-LocalDbConnectionString{
    return "$PsScriptRoot/../DotnetUserSecrets/GetLocalDbConnectionString.ps1" | Invoke-Expression
}

function Get-TestDbConnectionString{
    return "$PsScriptRoot/../DotnetUserSecrets/GetTestDbConnectionString.ps1" | Invoke-Expression
}

function Get-DatabaseName {
    param(
        [string]$ConnectionString
    )
    
    # If no connection string provided, get it from user secrets
    if ([string]::IsNullOrEmpty($ConnectionString)) {
        $ConnectionString = Get-LocalDbConnectionString
    }
    
    # Parse database name from connection string
    if ($ConnectionString -match "Database=([^;]+)") {
        return $matches[1]
    }
    
    # No database name found
    throw "Could not extract database name from connection string: $ConnectionString"
}

function Get-ServerConnectionString {
    param(
        [string]$ConnectionString
    )
    
    # If no connection string provided, get it from user secrets
    if ([string]::IsNullOrEmpty($ConnectionString)) {
        $ConnectionString = Get-LocalDbConnectionString
    }
    
    # Remove database specification from connection string
    return $ConnectionString -replace "Database=[^;]+;?", ""
}

function Get-OpenMySqlCmd {
  # SimplySql typically exposes Open-MySqlConnection. Some versions used Open-MySqlDBConnection.
  $cmd = Get-Command -Module SimplySql -Name Open-MySqlConnection -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Name }

  $alt = Get-Command -Module SimplySql -Name Open-MySqlDBConnection -ErrorAction SilentlyContinue
  if ($alt) { return $alt.Name }

  throw "Could not find SimplySql cmdlet: Open-MySqlConnection (or Open-MySqlDBConnection)."
}

function Open-SqlConnection {
    <#
    .SYNOPSIS
    Opens a database connection based on the specified database type.
    
    .PARAMETER ConnectionString
    The connection string for the database.
    
    .PARAMETER DatabaseType
    The type of database. Valid values: MySQL, MariaDB, SqlServer, Sqlite, PostgreSQL
    Default is MySQL.
    #>
    param(
        [string]$ConnectionString,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("MySQL", "MariaDB", "SqlServer", "Sqlite", "PostgreSQL")]
        [string]$DatabaseType = "MySQL"
    )
    
    switch ($DatabaseType) {
        "MySQL" {
            $cmdName = Get-OpenMySqlCmd
            & $cmdName -ConnectionString $ConnectionString
        }
        "MariaDB" {
            $cmdName = Get-OpenMySqlCmd
            & $cmdName -ConnectionString $ConnectionString
        }
        "SqlServer" {
            $cmd = Get-Command -Module SimplySql -Name Open-SqlConnection -ErrorAction SilentlyContinue
            if ($cmd) { 
                & $cmd.Name -ConnectionString $ConnectionString
            } else {
                throw "Could not find SimplySql cmdlet: Open-SqlConnection"
            }
        }
        "Sqlite" {
            $cmd = Get-Command -Module SimplySql -Name Open-SQLiteConnection -ErrorAction SilentlyContinue
            if ($cmd) { 
                & $cmd.Name -Path $ConnectionString
            } else {
                throw "Could not find SimplySql cmdlet: Open-SQLiteConnection"
            }
        }
        "PostgreSQL" {
            $cmd = Get-Command -Module SimplySql -Name Open-PostGreConnection -ErrorAction SilentlyContinue
            if ($cmd) { 
                & $cmd.Name -ConnectionString $ConnectionString
            } else {
                throw "Could not find SimplySql cmdlet: Open-PostGreConnection"
            }
        }
        default {
            throw "Unsupported database type: $DatabaseType"
        }
    }
}

function Test-DatabaseExists {
    <#
    .SYNOPSIS
    Checks if a database exists.
    
    .PARAMETER DatabaseName
    The name of the database to check.
    
    .DESCRIPTION
    Queries INFORMATION_SCHEMA.SCHEMATA to verify if the database exists.
    Returns $true if database exists, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName
    )
    
    try {
        $checkDbQuery = "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$DatabaseName';"
        $result = Invoke-SqlQuery -Query $checkDbQuery -ErrorAction Stop
        
        return $result.Count -gt 0
    } catch {
        throw "Failed to check if database exists: $_"
    }
}


function Remove-LocalDatabase {
    param(
        [string]$ConnectionString
    )
    $dropQuery = "DROP DATABASE ``$DatabaseName``;"
    Invoke-SqlQuery -Query $dropQuery
}

function Get-DatabaseTables {
    <#
    .SYNOPSIS
    Gets a list of all tables in the current database.
    
    .DESCRIPTION
    Executes SHOW TABLES and returns an array of table names.
    Requires an open database connection.
    #>
    
    try {
        $tablesQuery = "SHOW TABLES;"
        $tables = Invoke-SqlQuery -Query $tablesQuery -ErrorAction Stop
        
        if (-not $tables -or $tables.Count -eq 0) {
            return @()
        }
        
        # Convert table results to array of table names
        $tableNames = @()
        foreach ($table in $tables) {
            # The column name varies by MySQL/MariaDB version, so get the first property
            $tableName = $table.PSObject.Properties.Value | Select-Object -First 1
            $tableNames += $tableName
        }
        
        return $tableNames
    } catch {
        throw "Failed to get database tables: $_"
    }
}

function Get-TableRowCount {
    <#
    .SYNOPSIS
    Gets the row count for a specific table.
    
    .PARAMETER TableName
    The name of the table to count rows for.
    
    .DESCRIPTION
    Executes SELECT COUNT(*) for the specified table.
    Returns the count as an integer, or "Error" if the query fails.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName
    )
    
    try {
        $countQuery = "SELECT COUNT(*) as RowCount FROM ``$TableName``;"
        $countResult = Invoke-SqlQuery -Query $countQuery -ErrorAction Stop
        
        if ($countResult -and $countResult.Count -gt 0) {
            # SimplySql returns DataRow objects, the first item directly contains the count
            $count = $countResult[0]
            
            # If it's a complex object, try to extract the count value
            if ($count -is [System.Data.DataRow]) {
                # For DataRow, the first column contains the count
                $count = $count[0]
            }
            elseif ($count.PSObject.Properties['RowCount']) {
                $count = $count.RowCount
            }
            elseif ($count.PSObject.Properties['COUNT(*)']) {
                $count = $count.'COUNT(*)'
            }
            
            return $count
        } else {
            return "Unknown"
        }
    } catch {
        Write-Verbose "Could not get row count for table '$TableName': $_"
        return "Error"
    }
}

function Get-TableData {
    <#
    .SYNOPSIS
    Gets data from a specific table with optional row limit.
    
    .PARAMETER TableName
    The name of the table to query.
    
    .PARAMETER Limit
    Maximum number of rows to return. Default is 100.
    
    .DESCRIPTION
    Executes SELECT * FROM table with LIMIT clause.
    Returns the query results or null if table is empty.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName,
        
        [int]$Limit = 100
    )
    
    try {
        $dataQuery = "SELECT * FROM ``$TableName`` LIMIT $Limit;"
        $result = Invoke-SqlQuery -Query $dataQuery -ErrorAction Stop
        return $result
    } catch {
        throw "Failed to get data from table '$TableName': $_"
    }
}

function Show-TableDataInteractive {
    <#
    .SYNOPSIS
    Displays table data in an interactive format with row count and formatting.
    
    .PARAMETER TableName
    The name of the table to display.
    
    .PARAMETER Limit
    Maximum number of rows to display. Default is 100.
    
    .DESCRIPTION
    Gets table data and row count, then displays it with proper formatting and information.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName,
        
        [int]$Limit = 100
    )
    
    Write-Host "`nQuerying table: $TableName (limit $Limit rows)" -ForegroundColor Yellow
    
    # Get row count
    $totalRows = Get-TableRowCount -TableName $TableName
    Write-Host "Total rows in table: $totalRows" -ForegroundColor Gray
    
    # Get and display data
    $result = Get-TableData -TableName $TableName -Limit $Limit
    
    if ($result -and $result.Count -gt 0) {
        Write-Host "`nData from table '$TableName':" -ForegroundColor Green
        Write-Host $("=" * 60) -ForegroundColor Gray
        $result | Format-Table -AutoSize -Wrap
        
        if ($totalRows -ne "Unknown" -and $totalRows -ne "Error" -and $totalRows -gt $Limit) {
            Write-Host "Showing first $Limit of $totalRows rows. Use -Limit parameter to show more." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nTable '$TableName' is empty." -ForegroundColor Yellow
    }
}

function Get-RequiredDotNetVersion {
    <#
    .SYNOPSIS
    Reads the required .NET version from the project file.
    
    .PARAMETER ProjectPath
    Path to the .csproj file. Defaults to the main RecipesApi project.
    #>
    param(
        [string]$ProjectPath = "$PSScriptRoot/../../RecipesApi/RecipesApi.csproj"
    )
    
    if (-not (Test-Path $ProjectPath)) {
        throw "Project file not found: $ProjectPath"
    }
    
    $csprojContent = Get-Content $ProjectPath -Raw
    if ($csprojContent -match '<TargetFramework>([^<]+)</TargetFramework>') {
        return $matches[1]
    }
    
    throw "Could not find TargetFramework in project file: $ProjectPath"
}

function Test-DotNetVersion {
    <#
    .SYNOPSIS
    Checks if the required .NET SDK version is available.
    
    .PARAMETER RequiredVersion
    The required .NET version (e.g., "net9.0")
    #>
    param(
        [string]$RequiredVersion
    )
    
    # Get installed .NET version
    $dotnetVersion = $null
    try {
        $dotnetVersion = & dotnet --version 2>$null
    } catch {
        return @{
            Success = $false
            Message = ".NET SDK is not installed or not in PATH. Please install .NET SDK from: https://dotnet.microsoft.com/download"
            InstalledVersion = $null
            RequiredVersion = $RequiredVersion
        }
    }
    
    # Extract major version from target framework (e.g., "net9.0" -> "9")
    $requiredMajor = $null
    if ($RequiredVersion -match '^net(\d+)\.') {
        $requiredMajor = [int]$matches[1]
    } else {
        return @{
            Success = $false
            Message = "Invalid target framework format: $RequiredVersion"
            InstalledVersion = $dotnetVersion
            RequiredVersion = $RequiredVersion
        }
    }
    
    # Extract major version from installed version
    $installedMajor = $null
    if ($dotnetVersion -match '^(\d+)\.') {
        $installedMajor = [int]$matches[1]
    } else {
        return @{
            Success = $false
            Message = "Could not parse installed .NET version: $dotnetVersion"
            InstalledVersion = $dotnetVersion
            RequiredVersion = $RequiredVersion
        }
    }
    
    $success = $installedMajor -ge $requiredMajor
    
    return @{
        Success = $success
        Message = if ($success) { 
            ".NET SDK $dotnetVersion found (required: $RequiredVersion compatible)" 
        } else { 
            ".NET SDK $dotnetVersion found, but $RequiredVersion compatible version is required. Please install .NET $requiredMajor SDK or later." 
        }
        InstalledVersion = $dotnetVersion
        RequiredVersion = $RequiredVersion
    }
}

function Test-DatabaseCli {
    <#
    .SYNOPSIS
    Checks if MariaDB or MySQL CLI tools are available.
    #>
    
    # Try mariadb command first
    try {
        $null = & mariadb --version 2>$null
        return @{
            Success = $true
            Message = "MariaDB CLI found"
            Command = "mariadb"
        }
    } catch {
        # Try mysql command as fallback
        try {
            $null = & mysql --version 2>$null
            return @{
                Success = $true
                Message = "MySQL CLI found"
                Command = "mysql"
            }
        } catch {
            return @{
                Success = $false
                Message = "Neither MariaDB nor MySQL CLI is installed or in PATH. Please install one of the following:`n  • MariaDB: https://mariadb.org/download/`n  • MySQL: https://dev.mysql.com/downloads/mysql/`n`nAfter installation, make sure the CLI tools are in your PATH."
                Command = $null
            }
        }
    }
}

function Test-DatabaseConnection {
    <#
    .SYNOPSIS
    Tests if the database server is running and accessible. Does not test credentials.
    
    .PARAMETER Command
    The database CLI command to use (mariadb or mysql)
    #>
    param(
        [string]$Command = "mariadb"
    )
    
    try {
        # Test basic connectivity without credentials - this will fail auth but confirms server is running
        $testResult = & $Command --host=localhost --port=3306 -e "SELECT 1;" 2>&1
        $errorOutput = $testResult | Out-String
        
        # Check for connection-related errors (server not running)
        if ($errorOutput -match "Can't connect to|Connection refused|Unknown MySQL server host|Can't connect to MySQL server") {
            return @{
                Success = $false
                Message = "Database server appears to be not running or not accessible on localhost:3306"
            }
        }
        
        # If we get here, server is running (auth failure is expected and OK at this stage)
        return @{
            Success = $true
            Message = "Database server is running and accessible"
        }
    } catch {
        return @{
            Success = $false
            Message = "Database server appears to be not running or not accessible on localhost:3306"
        }
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
    Ensures all prerequisites for the RecipesApi project are met.
    
    .PARAMETER SkipDatabase
    Skip database-related prerequisite checks
    
    .PARAMETER ProjectPath
    Path to the project file to check .NET version requirements
    #>
    param(
        [switch]$SkipDatabase,
        [string]$ProjectPath = "$PSScriptRoot/../../RecipesApi/RecipesApi.csproj"
    )
    
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check .NET version
    $requiredVersion = Get-RequiredDotNetVersion -ProjectPath $ProjectPath
    $dotnetCheck = Test-DotNetVersion -RequiredVersion $requiredVersion
    
    if ($dotnetCheck.Success) {
        Write-Host "✓ $($dotnetCheck.Message)" -ForegroundColor Green
    } else {
        Write-Host "Error: $($dotnetCheck.Message)" -ForegroundColor Red
        return $false
    }


    $cliCheck = Test-DatabaseCli
    
    if ($cliCheck.Success) {
        Write-Host "✓ $($cliCheck.Message)" -ForegroundColor Green
    } else {
        Write-Host "Error: $($cliCheck.Message)" -ForegroundColor Red
        return $false
    }


    if (-not $SkipDatabase) {

            # Test database server connectivity (not credentials)
            Write-Host "Checking database server connectivity..." -ForegroundColor Yellow
            $connectionCheck = Test-DatabaseConnection -Command $cliCheck.Command
            
            if ($connectionCheck.Success) {
                Write-Host "✓ $($connectionCheck.Message)" -ForegroundColor Green
            } else {
                Write-Host "Warning: $($connectionCheck.Message)" -ForegroundColor Yellow
                Write-Host "Please ensure your MariaDB/MySQL server is running before proceeding." -ForegroundColor Yellow
                Write-Host ""
                $continue = Read-Host "Continue with setup anyway? (y/n)"
                if ($continue -ne "y" -and $continue -ne "Y") {
                    return $false
                }
            }
      
    }
    
    return $true
}