$rootPath = Resolve-Path "$PSScriptRoot/.."
$configPath = Join-Path $rootPath 'shtools.config.json'
if (-Not (Test-Path $configPath)) {
    throw "Config file not found: $configPath"
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json
return $config
