param(
    [Parameter(Mandatory=$false)]
    [string]$SqlFilePath
)



$cliCheck = Test-DatabaseCli
    
if ($cliCheck.Success) {
        Write-Host "✓ $($cliCheck.Message)" -ForegroundColor Green
} else {
    Write-Host "Error: $($cliCheck.Message)" -ForegroundColor Red
    return $false
}


# Get connection strings from DotnetUserSecrets scripts
$getMainConn = Join-Path $PSScriptRoot "..\DotnetUserSecrets\GetLocalDbConnectionString.ps1"
$getTestConn = Join-Path $PSScriptRoot "..\DotnetUserSecrets\GetTestDbConnectionString.ps1"

$mainConnStr = & $getMainConn
$testConnStr = & $getTestConn

function Parse-ConnStr {
    param([string]$connStr)
    $result = @{}
    foreach ($pair in $connStr -split ';') {
        if ($pair -match '=') {
            
            $k,$v = $pair -split '=',2
            $result[$k.Trim()] = $v.Trim()
        }
    }
    return $result
}

$mainConn = Parse-ConnStr $mainConnStr
$testConn = Parse-ConnStr $testConnStr

$mainDb = $mainConn['Database']
$testDb = $testConn['Database']


# Interactive selection of .sql file if not provided

if (-not $SqlFilePath) {
    
    Install-RequiredModule -Name PSMenu -Install

    Write-Host "Searching for .sql files in the repo..."
    $repoRoot = Resolve-Path "$PSScriptRoot/../../"
    $sqlFilesRaw = Get-ChildItem -Path $repoRoot -Recurse -Filter *.sql | Select-Object -ExpandProperty FullName
    $sqlFiles = @()
    if ($sqlFilesRaw -is [array]) {
        $sqlFiles = $sqlFilesRaw
    } elseif ($sqlFilesRaw) {
        $sqlFiles = @($sqlFilesRaw)
    }
    if ($sqlFiles.Count -eq 0) {
        Write-Error "No .sql files found in the repository."
        exit 1
    } elseif ($sqlFiles.Count -eq 1) {
        Write-Host "Found one .sql file: $($sqlFiles[0])" -ForegroundColor Yellow
        $SqlFilePath = $sqlFiles[0]
    } else {
        Write-Host "Select a .sql file to import:"
        $SqlFilePath = Show-Menu -MenuItems $sqlFiles
    }
}

if (-not (Test-Path $SqlFilePath)) {
    Write-Error "SQL file not found: $SqlFilePath"
    exit 1
}

# Drop and create both databases
Write-Host "Dropping and creating databases..."
& "$PSScriptRoot/CreateDatabase.ps1" -Force

# MariaDB client config (from connection string)
$user = $mainConn['User Id']
$pass = $mainConn['Password']
$port = $mainConn['Port']
$dbHost = $mainConn['Server']

function Import-SqlDump {
    param(
        [string]$dbName,
        [string]$sqlFile,
        [hashtable]$conn
    )
    Write-Host "`n===============================" -ForegroundColor Cyan
    Write-Host "IMPORTING SQL FILE" -ForegroundColor Magenta
    Write-Host "File: $sqlFile" -ForegroundColor Yellow
    Write-Host "Target DB: $dbName" -ForegroundColor Yellow
    Write-Host "===============================" -ForegroundColor Cyan
    $user = $conn['User Id']
    $pass = $conn['Password']
    $port = $conn['Port']
    $dbHost = $conn['Server']
    $cliCmd = $cliCheck.Command
    $cmd = "$cliCmd --user='$user' --password='$pass' --port=$port --host=$dbHost --database=$dbName < '$sqlFile'"
    Write-Host "Running: $cmd" -ForegroundColor DarkGray
    # Use cmd.exe to handle input redirection
    $fullCmd = "$cliCmd --user=$user --password=$pass --port=$port --host=$dbHost --database=$dbName < `"$sqlFile`""
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $fullCmd -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Error "Import failed for $dbName (exit code $($proc.ExitCode))"
        exit $proc.ExitCode
    }
}

Import-SqlDump -dbName $mainDb -sqlFile $SqlFilePath -conn $mainConn
Import-SqlDump -dbName $testDb -sqlFile $SqlFilePath -conn $testConn

Write-Host "`n=====================================" -ForegroundColor Green
Write-Host "DATABASE IMPORT COMPLETE!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
