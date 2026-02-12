#requires -Version 7.0


AfterAll {
  if ($script:mod) { Remove-Module $script:mod -Force -ErrorAction SilentlyContinue }
}


BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '\..\..\..\..\Src\ShTools.Core\ShTools.Core.psd1' 
    $script:mod = Import-Module $modulePath -Force -PassThru -ErrorAction Stop
    
    # Create test configuration
    $Script:TestConfig = @{
        GhProjectNumber = 6
        GhOwner = "testowner"
        GhRepo = "testowner/testrepo"
        _Cache = @{
            ProjectId = "PVT_kwHOAx1E6c4BGQlE"
            ProjectTitle = "Test Project"
            StatusField = @{
                Id = "PVTSSF_lAHOAx1E6c4BGQlEzg3W5Uw"
                Name = "Status"
                Type = "ProjectV2SingleSelectField"
            }
            StatusOptions = @{
                Backlog = @{
                    id = "f75ad846"
                    name = "Backlog"
                    key = "Backlog"
                    order = 0
                }
                Todo = @{
                    id = "61e4505c"
                    name = "Todo" 
                    key = "Todo"
                    order = 1
                }
                InProgress = @{
                    id = "47fc9ee4"
                    name = "In progress"
                    key = "InProgress"
                    order = 2
                }
                InReview = @{
                    id = "df73e18b"
                    name = "In review"
                    key = "InReview" 
                    order = 3
                }
                Done = @{
                    id = "98236657"
                    name = "Done"
                    key = "Done"
                    order = 4
                }
            }
            LastUpdated = "2025-10-28 14:06:30"
        }
    }
    
    # Mock GitHub API responses
    $Script:MockProjectInfo = @{
        id = "PVT_kwHOAx1E6c4BGQlE"
        number = 6
        title = "Test Project"
        url = "https://github.com/users/testowner/projects/6"
    }

    $Script:MockFieldList = @{
        fields = @(
            @{
                id = "PVTSSF_lAHOAx1E6c4BGQlEzg3W5Uw"
                name = "Status"
                type = "ProjectV2SingleSelectField"
                options = @(
                    @{ id = "f75ad846"; name = "Backlog" },
                    @{ id = "61e4505c"; name = "Todo" },
                    @{ id = "47fc9ee4"; name = "In progress" },
                    @{ id = "df73e18b"; name = "In review" },
                    @{ id = "98236657"; name = "Done" }
                )
            }
        )
    }

    $Script:MockItemList = @{
        items = @(
            @{
                id = "PVTI_lAHOAx1E6c4BGQlEzggbFWI"
                title = "Test API endpoint"
                status = "Todo"
                content = @{
                    type = "Issue"
                    number = 1
                    url = "https://github.com/testowner/testrepo/issues/1"
                }
            },
            @{
                id = "PVTI_lAHOAx1E6c4BGQlEzggbFuI"
                title = "Draft task item"
                status = "Backlog"
                content = @{
                    type = "DraftIssue"
                }
            },
            @{
                id = "PVTI_lAHOAx1E6c4BGQlEzggbFxX"
                title = "Fix authentication bug"
                status = "In progress"
                content = @{
                    type = "Issue"
                    number = 2
                    url = "https://github.com/testowner/testrepo/issues/2"
                }
            }
        )
    }
    
    # Empty mock for testing no matches scenario
    $Script:MockEmptyItemList = @{
        items = @()
    }

    $Script:MockIssue = @{
        number = 3
        title = "New test issue"
        body = "Test issue body"
        url = "https://github.com/testowner/testrepo/issues/3"
        state = "open"
        labels = @()
    }

    $Script:MockDraftItem = @{
        id = "PVTI_lAHOAx1E6c4BGQlEzggbNew"
        title = "New draft item"
        content = @{
            type = "DraftIssue"
        }
    }

    $Script:MockProjectItem = @{
        id = "PVTI_lAHOAx1E6c4BGQlEzggbAdd"
        content = @{
            type = "Issue"
            number = 3
            url = "https://github.com/testowner/testrepo/issues/3"
        }
    }
}

Describe 'GitHub CLI Wrapper Functions' {
    It 'Should have Invoke-GhProjectView function' {
        Get-Command -Module ShTools.Core -Name Invoke-GhProjectView | Should -Not -BeNullOrEmpty
    }
    
    It 'Should have Invoke-GhProjectItemList function' {
        Get-Command -Module ShTools.Core -Name Invoke-GhProjectItemList | Should -Not -BeNullOrEmpty
    }
    
    It 'Should have Invoke-GhIssueCreate function' {
        Get-Command -Module ShTools.Core -Name Invoke-GhIssueCreate | Should -Not -BeNullOrEmpty
    }
    
    It 'Should have Invoke-GhProjectItemEdit function' {
        Get-Command -Module ShTools.Core -Name Invoke-GhProjectItemEdit | Should -Not -BeNullOrEmpty
    }
    
    It 'Should have all wrapper functions exported' {
        $wrapperFunctions = @(
            'Invoke-GhProjectView',
            'Invoke-GhProjectFieldList', 
            'Invoke-GhProjectItemList',
            'Invoke-GhIssueCreate',
            'Invoke-GhProjectItemCreate',
            'Invoke-GhProjectItemAdd',
            'Invoke-GhProjectItemEdit',
            'Invoke-GhApiUser',
            'Invoke-GhIssueEdit',
            'Invoke-GhIssueView'
        )
        
        foreach ($func in $wrapperFunctions) {
            Get-Command -Module ShTools.Core $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$func should be exported"
        }
    }
}

Describe 'Configuration Tests' {
    Context 'Test-GhProjectConfig' {
        It 'Should return false for missing config file' {
            $result = Test-GhProjectConfig -ConfigPath "C:\NonExistent\config.json"
            $result | Should -Be $false
        }
        
        It 'Should return true for existing config file' {
            $tempConfig = Join-Path $TestDrive 'test-config.json'
            $Script:TestConfig | ConvertTo-Json -Depth 10 | Out-File $tempConfig -Encoding UTF8
            
            $result = Test-GhProjectConfig -ConfigPath $tempConfig
            $result | Should -Be $true
        }
    }
}

Describe 'Business Logic Functions with Mocked Data' {
    BeforeEach {
        # Set module configuration
        & (Get-Module ghproject) { 
            $Script:Config = $args[0]
            $Script:GhOwner = $args[0].GhOwner
            $Script:GhRepo = $args[0].GhRepo  
            $Script:GhProjectNumber = $args[0].GhProjectNumber
        } $Script:TestConfig
        
        # Mock all GitHub CLI wrapper functions
        Mock -ModuleName ghproject Invoke-GhProjectView { return $Script:MockProjectInfo }
        Mock -ModuleName ghproject Invoke-GhProjectFieldList { return $Script:MockFieldList }
        Mock -ModuleName ghproject Invoke-GhProjectItemList { return $Script:MockItemList }
        Mock -ModuleName ghproject Invoke-GhIssueCreate { return $Script:MockIssue }
        Mock -ModuleName ghproject Invoke-GhProjectItemCreate { return $Script:MockDraftItem }
        Mock -ModuleName ghproject Invoke-GhProjectItemAdd { return $Script:MockProjectItem }
        Mock -ModuleName ghproject Invoke-GhProjectItemEdit { 
            # Set successful exit code
            & (Get-Module ghproject) { $global:LASTEXITCODE = 0 }
            return "" 
        }
        Mock -ModuleName ghproject Invoke-GhApiUser { return "testuser" }
        Mock -ModuleName ghproject Invoke-GhIssueEdit { }
        Mock -ModuleName ghproject Invoke-GhIssueView { return "testuser" }
    }
    
    Context 'Find-ProjectItems' {
        It 'Should find items by title (partial match)' {
            $result = Find-ProjectItems -Title "API"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Title | Should -Be "Test API endpoint"
            $result[0].ProjectItemId | Should -Be "PVTI_lAHOAx1E6c4BGQlEzggbFWI"
            $result[0].Status | Should -Be "Todo"
            $result[0].Type | Should -Be "Issue"
            $result[0].IssueNumber | Should -Be 1
        }
        
        It 'Should find items by issue number' {
            $result = Find-ProjectItems -IssueNumber 2
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Title | Should -Be "Fix authentication bug"
            $result[0].IssueNumber | Should -Be 2
            $result[0].Status | Should -Be "In progress"
        }
        
        It 'Should find items by status' {
            $result = Find-ProjectItems -Status "Backlog"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Title | Should -Be "Draft task item"
            $result[0].Status | Should -Be "Backlog"
            $result[0].Type | Should -Be "DraftIssue"
        }
        
        It 'Should return empty result when no matches found' {
            # Mock empty response for this specific test
            Mock -ModuleName ghproject Invoke-GhProjectItemList { return $Script:MockEmptyItemList }
            
            $result = Find-ProjectItems -Title "NonExistent"
            
            # Result should be empty (array or null)
            if ($result) {
                $result | Should -BeOfType [Array]
                $result.Count | Should -Be 0
            } else {
                # Accepting null as valid empty result
                $result | Should -BeNullOrEmpty
            }
        }
        
        It 'Should handle multiple filter criteria' {
            $result = Find-ProjectItems -Status "Todo" -Title "API"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Title | Should -Be "Test API endpoint"
        }
    }
    
    Context 'New-RepoIssue' {
        It 'Should create issue with title and body' {
            $result = New-RepoIssue -Title "Test Issue" -Body "Test body"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Number | Should -Be 3
            $result.Title | Should -Be "New test issue"
            $result.Url | Should -Be "https://github.com/testowner/testrepo/issues/3"
            
            Should -Invoke -ModuleName ghproject Invoke-GhIssueCreate -Times 1 -Exactly
        }
        
        It 'Should create issue with title only (auto-generated body)' {
            $result = New-RepoIssue -Title "Test Issue"
            
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -ModuleName ghproject Invoke-GhIssueCreate -Times 1 -Exactly -ParameterFilter {
                $Body -eq "Issue created via automation script."
            }
        }
        
        It 'Should create issue with labels' {
            $result = New-RepoIssue -Title "Test Issue" -Body "Test body" -Labels @("bug", "enhancement")
            
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -ModuleName ghproject Invoke-GhIssueCreate -Times 1 -Exactly -ParameterFilter {
                $Labels -contains "bug" -and $Labels -contains "enhancement"
            }
        }
    }
    
    Context 'New-ProjectDraftItem' {
        It 'Should create draft item with title' {
            $result = New-ProjectDraftItem -Title "Test Draft"
            
            $result | Should -Be "PVTI_lAHOAx1E6c4BGQlEzggbNew"
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemCreate -Times 1 -Exactly
        }
        
        It 'Should create draft item with title and body' {
            $result = New-ProjectDraftItem -Title "Test Draft" -Body "Draft description"
            
            $result | Should -Be "PVTI_lAHOAx1E6c4BGQlEzggbNew"
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemCreate -Times 1 -Exactly -ParameterFilter {
                $Body -eq "Draft description"
            }
        }
    }
    
    Context 'Add-ProjectItemForIssue' {
        It 'Should add existing issue to project' {
            $result = Add-ProjectItemForIssue -IssueNumber 3
            
            $result | Should -Be "PVTI_lAHOAx1E6c4BGQlEzggbAdd"
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemAdd -Times 1 -Exactly -ParameterFilter {
                $IssueUrl -eq "https://github.com/testowner/testrepo/issues/3"
            }
        }
    }
    
    Context 'Set-ProjectItemStatus' {
        It 'Should update item status to valid status' {
            $result = Set-ProjectItemStatus -ItemId "PVTI_test123" -StatusKey "InProgress"
            
            $result | Should -Not -BeNullOrEmpty
            $result.ItemId | Should -Be "PVTI_test123"
            $result.StatusKey | Should -Be "InProgress"
            $result.Success | Should -Be $true
            
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemEdit -Times 1 -Exactly -ParameterFilter {
                $ItemId -eq "PVTI_test123" -and $OptionId -eq "47fc9ee4"
            }
        }
        
        It 'Should throw error for invalid status' {
            { Set-ProjectItemStatus -ItemId "PVTI_test123" -StatusKey "InvalidStatus" } | Should -Throw "*Invalid status*"
            
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemEdit -Times 0
        }
        
        It 'Should use correct project and field IDs' {
            $result = Set-ProjectItemStatus -ItemId "PVTI_test123" -StatusKey "Done"
            
            $result | Should -Not -BeNullOrEmpty
            $result.StatusKey | Should -Be "Done"
            
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemEdit -Times 1 -Exactly -ParameterFilter {
                $ProjectId -eq "PVT_kwHOAx1E6c4BGQlE" -and $FieldId -eq "PVTSSF_lAHOAx1E6c4BGQlEzg3W5Uw" -and $OptionId -eq "98236657"
            }
        }
    }
    
    Context 'Set-IssueAssignment' {
        It 'Should assign current user to issue' {
            { Set-IssueAssignment -IssueNumber 1 } | Should -Not -Throw
            
            Should -Invoke -ModuleName ghproject Invoke-GhApiUser -Times 1 -Exactly
            Should -Invoke -ModuleName ghproject Invoke-GhIssueEdit -Times 1 -Exactly -ParameterFilter {
                $IssueNumber -eq 1 -and $AddAssignee -eq "testuser"
            }
        }
        
        It 'Should handle API user failure gracefully' {
            Mock -ModuleName ghproject Invoke-GhApiUser { return $null }
            
            $result = Set-IssueAssignment -IssueNumber 1
            
            $result | Should -Be $false
            Should -Invoke -ModuleName ghproject Invoke-GhIssueEdit -Times 0
        }
    }
    
    Context 'New-ProjectItem Integration' {
        It 'Should create issue and add to project for Issue type' {
            $result = New-ProjectItem -Title "Integration Test Issue" -Type "Issue" -Status "Todo"
            
            $result | Should -Not -BeNullOrEmpty
            $result.issue | Should -Not -BeNullOrEmpty
            $result.issue.Number | Should -Be 3
            $result.projectItemId | Should -Be "PVTI_lAHOAx1E6c4BGQlEzggbAdd"
            
            Should -Invoke -ModuleName ghproject Invoke-GhIssueCreate -Times 1 -Exactly
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemAdd -Times 1 -Exactly
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemEdit -Times 1 -Exactly
        }
        
        It 'Should create draft item for Draft type' {
            $result = New-ProjectItem -Title "Integration Test Draft" -Type "Draft" -Status "Backlog"
            
            $result | Should -Not -BeNullOrEmpty
            $result.ProjectItemId | Should -Be "PVTI_lAHOAx1E6c4BGQlEzggbNew"
            
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemCreate -Times 1 -Exactly
            Should -Invoke -ModuleName ghproject Invoke-GhProjectItemEdit -Times 1 -Exactly
        }
    }
}

Describe 'Error Handling and Edge Cases' {
    BeforeEach {
        & (Get-Module ghproject) { 
            $Script:Config = $args[0]
        } $Script:TestConfig
    }
    
    Context 'GitHub API Failures' {
        It 'Should handle Invoke-GhProjectItemList failure gracefully' {
            Mock -ModuleName ghproject Invoke-GhProjectItemList { throw "GitHub API Error" }
            
            # This should not throw, but should handle the error gracefully
            { Find-ProjectItems -Title "test" } | Should -Not -Throw
            
            # Result should be empty when API fails (array or null)
            $result = Find-ProjectItems -Title "test"
            if ($result) {
                $result | Should -BeOfType [Array]
                $result.Count | Should -Be 0
            } else {
                # Accepting null as valid empty result for API failures
                $result | Should -BeNullOrEmpty
            }
        }
        
        It 'Should handle invalid configuration gracefully' {
            & (Get-Module ghproject) { $Script:Config = $null }
            
            # With our improved error handling, this should not throw but return empty
            $result = Find-ProjectItems -Title "test"
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Configuration Validation' {
    It 'Should have valid status options with correct structure' {
        $statusOptions = $Script:TestConfig._Cache.StatusOptions
        
        $statusOptions.Keys | Should -Contain "Todo"
        $statusOptions.Keys | Should -Contain "InProgress" 
        $statusOptions.Keys | Should -Contain "Done"
        
        $statusOptions.Todo.id | Should -Be "61e4505c"
        $statusOptions.InProgress.id | Should -Be "47fc9ee4" 
        $statusOptions.Done.id | Should -Be "98236657"
    }
    
    It 'Should have proper status ordering' {
        $statusOptions = $Script:TestConfig._Cache.StatusOptions
        
        $statusOptions.Backlog.order | Should -Be 0
        $statusOptions.Todo.order | Should -Be 1
        $statusOptions.InProgress.order | Should -Be 2
        $statusOptions.InReview.order | Should -Be 3
        $statusOptions.Done.order | Should -Be 4
    }
    
    It 'Should have required field IDs' {
        $config = $Script:TestConfig
        
        $config._Cache.StatusField.Id | Should -Be "PVTSSF_lAHOAx1E6c4BGQlEzg3W5Uw"
        $config._Cache.StatusField.Name | Should -Be "Status"
        $config._Cache.ProjectId | Should -Be "PVT_kwHOAx1E6c4BGQlE"
        $config.GhProjectNumber | Should -Be 6
        $config.GhOwner | Should -Be "testowner"
    }
}
