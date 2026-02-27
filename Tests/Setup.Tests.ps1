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
        Mock Show-SetupConfigurationStatus { }
        Mock Write-Host { }
        Mock Write-Warning { }
    }

    It 'cancels when user declines to continue' {
        Mock Confirm-ContinueSetup { $false }
        Mock Show-SetupMenu { @() }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Show-SetupConfigurationStatus -Times 1 -Exactly
        Should -Invoke Confirm-ContinueSetup -Times 1 -Exactly
        
    }

    It 'cancels when no components are selected from menu' {
        Mock Confirm-ContinueSetup { $true }
        Mock Show-SetupMenu { @() }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Show-SetupConfigurationStatus -Times 1 -Exactly
        Should -Invoke Confirm-ContinueSetup -Times 1 -Exactly
        Should -Invoke Show-SetupMenu -Times 1 -Exactly
    }

    It 'runs selected setup components after confirmations' {
        Mock Confirm-ContinueSetup { $true }
        Mock Confirm-ProceedWithSetup { $true }
        Mock Show-SetupMenu {
            @(
                'Git Repository Setup',
                '.NET Project Settings'
            )
        }
        Mock Invoke-SetupComponent { }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Confirm-ContinueSetup -Times 1 -Exactly
        Should -Invoke Confirm-ProceedWithSetup -Times 1 -Exactly
        Should -Invoke Invoke-SetupComponent -Times 1 -Exactly -ParameterFilter { $ComponentName -eq 'Git Repository Setup' }
        Should -Invoke Invoke-SetupComponent -Times 1 -Exactly -ParameterFilter { $ComponentName -eq '.NET Project Settings' }
    }

    It 'asks to continue with remaining components after a component failure' {
        Mock Confirm-ContinueSetup { $true }
        Mock Confirm-ProceedWithSetup { $true }
        Mock Show-SetupMenu {
            @(
                'Git Repository Setup',
                '.NET Project Settings'
            )
        }
        Mock Invoke-SetupComponent {
            throw 'simulated component path failure'
        } -ParameterFilter {
            $ComponentName -eq 'Git Repository Setup'
        }

        Mock Invoke-SetupComponent { } -ParameterFilter {
            $ComponentName -eq '.NET Project Settings'
        }

        Mock Confirm-ProceedWithSettingUpComponentsDespiteError { $false }

        & $script:scriptPath -RootDirectory $script:testRootDirectory

        Should -Invoke Confirm-ProceedWithSettingUpComponentsDespiteError -Times 1 -Exactly
        Should -Invoke Invoke-SetupComponent -Times 1 -Exactly -ParameterFilter { $ComponentName -eq 'Git Repository Setup' }
        Should -Invoke Invoke-SetupComponent -Times 0 -Exactly -ParameterFilter { $ComponentName -eq '.NET Project Settings' }
    }
}