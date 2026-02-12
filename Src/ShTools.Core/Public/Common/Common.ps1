function Install-RequiredModule {
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [switch]$Install
  )

  $mod = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $mod) {
    if (-not $Install) {
      throw "Module '$Name' is not installed. Re-run with -Install to install automatically."
    }

    Write-Host "Installing module '$Name' for current user..."
    Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
  }

  Import-Module $Name -ErrorAction Stop
}





