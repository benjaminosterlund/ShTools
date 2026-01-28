Describe 'Select-DotnetProject' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\..\..\ShTools-Src\ShTools.Core\ShTools.Core.psd1'
        $script:mod = Import-Module $modulePath -Force -PassThru -ErrorAction Stop
    }

    Context 'When a valid -ProjectPath is provided' {
        It 'returns resolved path when ProjectPath exists' {
            InModuleScope $script:mod.Name {
                Mock Test-Path { $true }
                Mock Resolve-Path { [pscustomobject]@{ Path = 'C:\x\a.csproj' } }
                Select-DotnetProject -ProjectPath '.\a.csproj' | Should -Be 'C:\x\a.csproj'
            }
        }
    }

    Context 'When no csproj exists' {
        It 'throws when no projects found' {
            InModuleScope $script:mod.Name {
                Mock Get-ChildItem { @() }
                { Select-DotnetProject } | Should -Throw 'No .csproj files found.'
            }
        }
    }

    Context 'when exactly one csproj exists' {
        It 'returns single project automatically' {
            InModuleScope $script:mod.Name {
                Mock Get-ChildItem { @([pscustomobject]@{ FullName = 'a.csproj' }) }
                Mock Test-Path { $true }
                Select-DotnetProject | Should -Be 'a.csproj'
            }
        }
    }

    Context 'Single project outside context' {
        It 'returns single project automatically' {
            InModuleScope $script:mod.Name {
                Mock Get-ChildItem { [pscustomobject]@{ FullName = 'a.csproj' } }
                Select-DotnetProject | Should -Be 'a.csproj'
            }
        }
    }
}