
Describe 'DotnetUserSecrets Module' {
    BeforeAll {
            $modulePath = Join-Path $PSScriptRoot '\..\..\Src\ShTools.Core\ShTools.Core.psd1' 
            $script:mod = Import-Module $modulePath -Force -PassThru -ErrorAction Stop
    }

    It 'module is loaded' {
        $script:mod | Should -Not -BeNullOrEmpty
        (Get-Module $script:mod.Name) | Should -Not -BeNullOrEmpty
    }


    It 'exports functions' {
        $exports = $script:mod.ExportedFunctions.Keys
        $exports | Should -Not -BeNullOrEmpty
        $exports | Should -Contain 'Initialize-ProjectUserSecrets'
        $exports | Should -Contain 'Test-DotnetUserSecretsInitialized'
        $exports | Should -Contain 'Select-DotnetProject'
        $exports | Should -Contain 'Select-DotnetProjects'
    }

    It 'shows PowerShell version' {
        "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)" | Should -Not -BeNullOrEmpty
    }

}