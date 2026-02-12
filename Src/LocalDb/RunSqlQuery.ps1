# install 10.6.17-MariaDB (https://mariadb.org/mariadb/all-releases/)

# https://mariadb.com/downloads/ (11.8.3)


param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    [ValidateSet('localdb','testdb')]
    [string]$Database = 'localdb'
)

Install-RequiredModule -Name SimplySql -Install


if ($Database -eq 'localdb') {
    $ConnectionString = Get-LocalDbConnectionString
} elseif ($Database -eq 'testdb') {
    $ConnectionString = Get-TestDbConnectionString
} else {
    Write-Host "Unknown database selection: $Database" -ForegroundColor Red
    exit 1
}


try {
    Open-MySqlConnection -ConnectionString $ConnectionString -ErrorAction Stop
    $result = Invoke-SqlQuery -Query $Query -ErrorAction Stop
    $result | Format-Table -AutoSize
} catch {
    Write-Host "Error running query: $_" -ForegroundColor Red
    exit 1
} finally {
    Close-SqlConnection
}