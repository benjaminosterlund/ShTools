

Describe 'Initialize-ProjectUserSecrets' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '\..\..\..\..\Src\ShTools.Core\ShTools.Core.psd1' 
        $script:mod = Import-Module $modulePath -Force -PassThru -ErrorAction Stop
    }

    It 'returns false and does not call dotnet when project file is missing' {
        function dotnet { throw "dotnet should not be called" }

        $result = Initialize-ProjectUserSecrets -ProjectFile 'nonexistent.csproj' -ProjectName 'FakeProject'
        $result | Should -BeFalse
    }
}

