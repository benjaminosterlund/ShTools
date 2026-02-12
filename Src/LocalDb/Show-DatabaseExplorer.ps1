# Interactive Database Browser - Simple and focused
param(
    [int]$Limit = 100  # Default row limit to prevent overwhelming output
)

# Import helpers and ensure required modules
Install-RequiredModule -Name SimplySql -Install
Install-RequiredModule -Name PSMenu -Install

$ConnectionString = Get-LocalDbConnectionString

try {
    # Get list of tables
    Write-Host "Connecting to database and fetching table list..." -ForegroundColor Cyan
    Open-MySqlConnection -ConnectionString $ConnectionString -ErrorAction Stop
    
    $tableNames = Get-DatabaseTables
    
    if (-not $tableNames -or $tableNames.Count -eq 0) {
        Write-Host "No tables found in the database." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Found $($tableNames.Count) tables in the database." -ForegroundColor Green
    
    do {
        # Show table selection menu
        Write-Host "`nSelect a table to browse:" -ForegroundColor Cyan
        $selectedTable = Show-Menu -MenuItems $tableNames
        
        if ($selectedTable) {
            Show-TableDataInteractive -TableName $selectedTable -Limit $Limit
            
            # Ask if user wants to continue
            Write-Host "`nPress Enter to select another table, or 'q' to quit..." -ForegroundColor Cyan
            $continue = Read-Host
            if ($continue -eq 'q') {
                break
            }
        } else {
            break
        }
        
    } while ($true)
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Close-SqlConnection
    Write-Host "`nDisconnected from database." -ForegroundColor Gray
}

Write-Host "Database browser completed." -ForegroundColor Green