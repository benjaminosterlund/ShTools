param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,
    [switch]$ForTests
)

$ProjectPath = Select-DotnetProject -ProjectPath:$ProjectPath

$connectionStringKey = if ($ForTests) { "ConnectionStrings:TestConnection" } else { "ConnectionStrings:DefaultConnection" }

$connectionString = dotnet user-secrets list --project $ProjectPath | Where-Object { $_ -match "^$connectionStringKey" } | ForEach-Object { ($_ -split '=', 2)[1].Trim() }

return $connectionString