param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath
)

return & GetLocalDbConnectionString.ps1 -ProjectPath:$ProjectPath -ForTests