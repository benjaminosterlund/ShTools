Describe 'Setup' {
    BeforeAll {
        $ShToolsSrc = Join-Path $PSScriptRoot '..\Src'
        $script:scriptPath = Join-Path $ShToolsSrc 'Setup.ps1'

        $modulePath = Join-Path $ShToolsSrc "ShTools.Core\ShTools.Core.psd1"
        Import-Module $modulePath -Force
    }

    BeforeEach {
        $script:testRootDirectory = Join-Path $TestDrive 'root'


        Mock Import-PSMenuIfAvailable { }

        Mock Get-ConfigurationStatus { @{ IsConfigured = $false } }
        Mock Show-ConfigurationStatus { }
        Mock Write-Host { }
        Mock Write-Warning { }
    }

    It 'cancels when user declines to continue' {
        Mock Confirm-ContinueSetup { $false }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Confirm-ContinueSetup -Times 1 -Exactly
        Should -Invoke Show-ConfigurationStatus -Times 1 -Exactly
    }

    It 'cancels when no components are selected from menu' {
        Mock Confirm-ContinueSetup { $true }
        Mock Show-Menu { @() }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Confirm-ContinueSetup -Times 1 -Exactly
        Should -Invoke Show-Menu -Times 1 -Exactly
    }

    It 'runs selected setup components after confirmations' {
        Mock Confirm-ContinueSetup { $true }
        Mock Confirm-ProceedWithSetup { $true }
        Mock Show-Menu {
            @(
                'Git Repository Setup - anything',
                '.NET Project Settings - anything'
            )
        }

        Mock Test-Path { $false } -ParameterFilter {
            $Path -like '*\Git\InitGit.ps1' -or $Path -like '*\Dotnet\InitDotnet.ps1'
        }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Confirm-ContinueSetup -Times 1 -Exactly
        Should -Invoke Confirm-ProceedWithSetup -Times 1 -Exactly
        Should -Invoke Test-Path -Times 1 -ParameterFilter { $Path -like '*\Git\InitGit.ps1' }
        Should -Invoke Test-Path -Times 1 -ParameterFilter { $Path -like '*\Dotnet\InitDotnet.ps1' }
    }

    It 'asks to continue with remaining components after a component failure' {
        Mock Confirm-ContinueSetup { $true }
        Mock Confirm-ProceedWithSetup { $true }
        Mock Show-Menu {
            @(
                'Git Repository Setup - anything',
                '.NET Project Settings - anything'
            )
        }
        Mock Test-Path {
            throw 'simulated component path failure'
        } -ParameterFilter {
            $Path -like '*\Git\InitGit.ps1'
        }

        Mock Test-Path { $false } -ParameterFilter {
            $Path -like '*\Dotnet\InitDotnet.ps1'
        }

        Mock Read-YesNo { $false } -ParameterFilter {
            $Title -eq 'Continue with remaining components?'
        }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Read-YesNo -Times 1 -Exactly -ParameterFilter {
            $Title -eq 'Continue with remaining components?' -and $DefaultYes -eq $false
        }
    }
}