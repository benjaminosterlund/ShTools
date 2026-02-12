function Get-DotnetTemplate {

    $lines = dotnet new list

    # Find the separator line index
    $separatorIndex = $lines |
        Select-String '^-{2,}' |
        Select-Object -First 1 |
        ForEach-Object { $_.LineNumber - 1 }

    if (-not $separatorIndex) {
        throw "Could not detect template table format."
    }

    $dataLines = $lines | Select-Object -Skip ($separatorIndex + 1)

    foreach ($line in $dataLines) {

        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = $line -split '\s{2,}'

        [PSCustomObject]@{
            Name      = $parts[0]
            ShortName = $parts[1]
            Language  = $parts[2]
            Tags      = $parts[3]
        }
    }
}


#Example usage: Get-DotnetTemplate | Where-Object ShortName -eq 'webapi'
Get-DotnetTemplate