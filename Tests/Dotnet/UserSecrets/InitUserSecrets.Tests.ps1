# Pester tests for InitUserSecrets.ps1


BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..\..\..\Src\ShTools.Core\ShTools.Core.psd1'
  Import-Module $modulePath -Force -ErrorAction Stop
}


Describe 'InitUserSecrets' {

  BeforeEach {
    Mock -ModuleName ShTools.Core Invoke-DotnetUserSecrets {
      param(
        [string]$Action,
        [string]$ProjectFile
      )

      if ($Action -eq 'init') {
        $csprojContent = Get-Content $ProjectFile -Raw
        if ($csprojContent -notmatch '<UserSecretsId>') {
          $updatedContent = $csprojContent -replace '(<PropertyGroup[^>]*>)', "`$1`n    <UserSecretsId>test-secrets-id</UserSecretsId>"
          Set-Content -Path $ProjectFile -Value $updatedContent -NoNewline
        }
      }

      return [PSCustomObject]@{
        Success = $true
        ExitCode = 0
        Output = ''
      }
    }
  }

    It 'runs the script successfully' {

        # Arrange
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\Src\Dotnet\UserSecrets\InitUserSecrets.ps1'
        $mainProjectPath = Join-Path $TestDrive 'testproj.csproj'
        $testProjectPath = Join-Path $TestDrive 'testproj.tests.csproj'

        @"
<Project Sdk=""Microsoft.NET.Sdk"">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <AssemblyName>testproj</AssemblyName>
  </PropertyGroup>
</Project>
"@ | Set-Content -Path $mainProjectPath -Encoding UTF8

        @"
<Project Sdk=""Microsoft.NET.Sdk"">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <AssemblyName>testproj.tests</AssemblyName>
  </PropertyGroup>
</Project>
"@ | Set-Content -Path $testProjectPath -Encoding UTF8

        #Act
        $result = & $scriptPath -ProjectPath $mainProjectPath -TestProjectPath $testProjectPath

        # Assert
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match 'Done'

        Test-Path $mainProjectPath | Should -BeTrue
        Test-Path $testProjectPath | Should -BeTrue
        (Get-Content $mainProjectPath -Raw) | Should -Match '<UserSecretsId>'
        (Get-Content $testProjectPath -Raw) | Should -Match '<UserSecretsId>'

        Should -Invoke -ModuleName ShTools.Core Invoke-DotnetUserSecrets -Times 2 -Exactly -ParameterFilter {
          $Action -eq 'init'
        }
    }

}