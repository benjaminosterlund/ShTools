# Pester tests for InitUserSecrets.ps1


Describe 'InitUserSecrets' {

    It 'runs the script successfully' {

        # Arrange
        $scriptPath = Join-Path $PSScriptRoot '..\..\Src\DotnetUserSecrets\InitUserSecrets.ps1'

        #Act
        $result = & $scriptPath  -ProjectPath (Join-Path $PSScriptRoot '..\..\TestCsProj\testproj.csproj') -TestProjectPath (Join-Path $PSScriptRoot '..\..\TestCsProj\testproj.tests.csproj')

        # Assert
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match 'Done'
    }

}