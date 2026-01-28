function Initialize-ProjectUserSecrets {
    param(
        [string]$ProjectFile,
        [string]$ProjectName,
        [switch]$Reset
    )
    
    if (-not (Test-Path $ProjectFile)) {
        Write-Host "Warning: Project file not found: $ProjectFile" -ForegroundColor Yellow
        return $false
    }
    
    $csprojContent = Get-Content $ProjectFile -Raw
    $hasUserSecrets = $csprojContent -match '<UserSecretsId>'
    
    if ($hasUserSecrets -and -not $Reset) {
        Write-Host "✓ UserSecretsId already present in $ProjectName. Skipping initialization." -ForegroundColor Green
        return $true
    }
    
    if ($Reset -and $hasUserSecrets) {
        Write-Host "Resetting user secrets for $ProjectName..." -ForegroundColor Yellow
        
        # Clear all existing secrets
        Write-Host "Clearing existing secrets for $ProjectName..." -ForegroundColor Yellow
        & dotnet user-secrets clear --project $ProjectFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Existing secrets cleared for $ProjectName." -ForegroundColor Green
        } else {
            Write-Host "Failed to clear existing secrets for $ProjectName." -ForegroundColor Red
            return $false
        }
    }
    
    Write-Host "Initializing dotnet user-secrets for $ProjectName..." -ForegroundColor Yellow
    & dotnet user-secrets init --project $ProjectFile
    if ($LASTEXITCODE -eq 0) {
        if ($Reset) {
            Write-Host "✓ dotnet user-secrets reset and reinitialized successfully for $ProjectName." -ForegroundColor Green
        } else {
            Write-Host "✓ dotnet user-secrets initialized successfully for $ProjectName." -ForegroundColor Green
        }
        return $true
    } else {
        Write-Host "dotnet user-secrets init failed for $ProjectName." -ForegroundColor Red
        return $false
    }
}



function Test-DotnetUserSecretsInitialized {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    if (-not (Test-Path $ProjectPath -PathType Leaf)) {
        throw "Project file '$ProjectPath' does not exist."
    }

    # Load csproj as XML
    [xml]$xml = Get-Content $ProjectPath -Raw

    # Look for UserSecretsId anywhere
    $xml.Project.PropertyGroup.UserSecretsId |
        Where-Object { $_ -and $_.Trim() } |
        Select-Object -First 1 |
        ForEach-Object { return $true }

    return $false
}


