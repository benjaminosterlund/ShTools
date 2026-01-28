@{
    RootModule        = 'ShTools.Core.psm1'
    ModuleVersion     = '0.1.0'

    # Internal module – users don't import directly
    Description       = 'Internal core functions for ShTools scripts'

    PowerShellVersion = '7.2'

    FunctionsToExport = '*'   # psm1 controls this
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    RequiredModules = @(
        'Pester',
        @{ ModuleName = 'PSMenu'; ModuleVersion = '0.2.0' }
    )

    PrivateData = @{
        PSData = @{
            Tags = @('internal', 'ShTools')
        }
    }
}