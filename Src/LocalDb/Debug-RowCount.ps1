# Debug script for row count issue

Install-RequiredModule -Name SimplySql -Install

$ConnectionString = Get-LocalDbConnectionString

try {
    Open-MySqlConnection -ConnectionString $ConnectionString -ErrorAction Stop
    
    $result = Invoke-SqlQuery -Query "SELECT COUNT(*) as RowCount FROM *;" -ErrorAction Stop
    
    Write-Host "Result type: $($result.GetType())" -ForegroundColor Cyan
    Write-Host "Result count: $($result.Count)" -ForegroundColor Cyan
    Write-Host "First item: $($result[0])" -ForegroundColor Yellow
    Write-Host "First item type: $($result[0].GetType())" -ForegroundColor Yellow
    
    Write-Host "`nProperties:" -ForegroundColor Green
    $result[0] | Get-Member -MemberType Properties | Select-Object Name, Definition
    
    Write-Host "`nProperty values:" -ForegroundColor Green
    $result[0].PSObject.Properties | ForEach-Object { 
        Write-Host "  $($_.Name) = $($_.Value)" 
    }
    
} finally {
    Close-SqlConnection
}