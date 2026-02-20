$PublicPath  = Join-Path $PSScriptRoot 'Public'
$PrivatePath = Join-Path $PSScriptRoot 'Private'

# Load private helpers
if (Test-Path $PrivatePath) {
    Get-ChildItem $PrivatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Load public functions
if (Test-Path $PublicPath) {
    Get-ChildItem $PublicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# # Export ONLY functions with same name as scriptfile in public folder
# if (Test-Path $PublicPath) {
#     $publicFunctions = Get-ChildItem $PublicPath -Filter '*.ps1' -Recurse |
#         ForEach-Object { $_.BaseName }

#     Export-ModuleMember -Function $publicFunctions
# }



# Dot-source public files first
$publicFiles = Get-ChildItem $PublicPath -Filter '*.ps1' -Recurse
foreach ($f in $publicFiles) { . $f.FullName }

# Export functions whose ScriptBlock came from those files
$publicFilePaths = $publicFiles.FullName

$functionsToExport =
    Get-Command -CommandType Function |
    Where-Object {
        $_.ScriptBlock -and $_.ScriptBlock.File -and
        ($publicFilePaths -contains $_.ScriptBlock.File)
    } |
    Select-Object -ExpandProperty Name

Export-ModuleMember -Function $functionsToExport