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





# --- Module Dependencies ----------------------------------------------------

function Import-PSMenuIfAvailable {
    <#
    .SYNOPSIS
        Import PSMenu module if available, install if needed with user consent.
    .DESCRIPTION
        Checks for PSMenu module and imports it for better interactive menus.
        If not found, offers to install it from PowerShell Gallery.
    #>
    try {
        if (Get-Module -Name PSMenu -ListAvailable -ErrorAction SilentlyContinue) {
            Import-Module PSMenu -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Host "📋 PSMenu module not found. This provides better interactive menus." -ForegroundColor Yellow
            $install = Read-Host "Install PSMenu from PowerShell Gallery? (y/N)"
            if ($install -eq 'y' -or $install -eq 'Y') {
                Write-Host "Installing PSMenu..." -ForegroundColor Cyan
                Install-Module -Name PSMenu -Scope CurrentUser -Force
                Import-Module PSMenu -Force
                Write-Host "✅ PSMenu installed and imported!" -ForegroundColor Green
                return $true
            } else {
                Write-Host "PSMenu not installed. Will use basic console menus." -ForegroundColor Gray
                return $false
            }
        }
    } catch {
        Write-Warning "Failed to import PSMenu: $($_.Exception.Message). Using basic menus."
        return $false
    }
}