# install 10.6.17-MariaDB (https://mariadb.org/mariadb/all-releases/)

# https://mariadb.com/downloads/ (11.8.3)


param(
    [ValidateSet('localdb','testdb')]
    [string]$Database = 'localdb'
)


$Query = @"
  SELECT
  VERSION() AS version,
  @@hostname AS host,
  DATABASE() AS current_db,
  USER() AS user_name;
"@

& .\RunSqlQuery.ps1 -Query:$Query -Database:$Database