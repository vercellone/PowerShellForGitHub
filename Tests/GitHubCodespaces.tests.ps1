# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

<#
.Synopsis
   Tests for GitHubCodespaces.ps1 module
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Suppress false positives in Pester code blocks')]
param()

# This is common test code setup logic for all Pester test files
BeforeAll {
    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common.ps1')

    # Define Script-scoped, readonly, hidden variables.
    @{
        defaultRepositoryName = ([Guid]::NewGuid().Guid)
    }.GetEnumerator() | ForEach-Object {
        Set-Variable -Force -Scope Script -Option ReadOnly -Visibility Private -Name $_.Key -Value $_.Value
    }

    $newGitHubRepositoryParms = @{
        AutoInit = $true
        Private = $true
        RepositoryName = $defaultRepositoryName
        OrganizationName = $script:organizationName
    }
    $repo = New-GitHubRepository @newGitHubRepositoryParms
}

Describe 'GitHubCodespaces\Delete-GitHubCodespace' {

    Context 'When deleting a codespace for the authenticated user' {
        BeforeEach {
            # Suppress HTTP 202 warning for codespace creation
            # TODO: Suppression is not working as intended here.
            $WarningPreference = 'SilentlyContinue'

            $newGitHubCodespaceParms = @{
                OwnerName = $script:organizationName
                RepositoryName = $defaultRepositoryName
            }
            $codespace = New-GitHubCodespace @newGitHubCodespaceParms
            Start-Sleep -Seconds 3
        }

        It 'Should get no content using -Confirm:$false' {
            # Also asserts pipeline input
            $codespace | Remove-GitHubCodespace -Confirm:$false
            { Get-GitHubCodespace -CodespaceName $codespace.name } | Should -Throw
        }

        It 'Should get no content using -Force' {
            # Also assert CodespaceName input
            Remove-GitHubCodespace -CodespaceName $codespace.name -Force
            { Get-GitHubCodespace -CodespaceName $codespace.name } | Should -Throw
        }
    }
}

Describe 'GitHubCodespaces\Get-GitHubCodespace' {
    BeforeAll {
        # Suppress HTTP 202 warning for codespace creation
        $WarningPreference = 'SilentlyContinue'

        $newGitHubCodespaceParms = @{
            OwnerName = $script:organizationName
            RepositoryName = $defaultRepositoryName
        }
        $null = New-GitHubCodespace @newGitHubCodespaceParms
        Start-Sleep -Seconds 3
    }

    Context 'When getting codespaces for the authenticated user' {
        BeforeAll {
            $codespaces = Get-GitHubCodespace |
            Where-Object { $_.repository.name -eq $defaultRepositoryName }
        }

        It 'Should return objects of the correct type' {
            $codespaces[0].PSObject.TypeNames[0] | Should -Be 'GitHub.Codespace'
        }

        It 'Should return one or more results' {
            $codespaces.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should return the correct properties' {
            foreach ($codespace in $codespaces)
            {
                $codespace.owner.login | Should -Be $script:OwnerName
                $codespace.repository.name | Should -Be $newGitHubCodespaceParms.RepositoryName
            }
        }
    }

    Context 'When getting a codespace for a specified owner and repository' {

        BeforeAll {
            $codespaces = Get-GitHubCodespace @newGitHubCodespaceParms
        }
        It 'Should return objects of the correct type' {
            $codespaces[0].PSObject.TypeNames[0] | Should -Be 'GitHub.Codespace'
        }

        It 'Should return one or more results' {
            $codespaces.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should return the correct properties' {
            foreach ($codespace in $codespaces)
            {
                $codespace.owner.login | Should -Be $script:OwnerName
                $codespace.repository.name | Should -Be $newGitHubCodespaceParms.RepositoryName
            }
        }
    }

    Context 'When getting all codespaces for a specified organization' {

        BeforeAll {
            $codespaces = Get-GitHubCodespace -OrganizationName $script:organizationName
        }
        It 'Should return objects of the correct type' {
            $codespaces[0].PSObject.TypeNames[0] | Should -Be 'GitHub.Codespace'
        }

        It 'Should return one or more results' {
            $codespaces.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'When getting a codespace for a specified organization user' {
        BeforeAll {
            $codespaces = Get-GitHubCodespace -OrganizationName $script:organizationName
            $userCodespaces = Get-GitHubCodespace -OrganizationName $script:organizationName -UserName $script:OwnerName
        }

        It 'Should have results for the organization user' {
            $userCodespaces.name | Should -BeIn $codespaces.name
        }

        It 'Should return the correct properties' {
            foreach ($codespace in $userCodespaces)
            {
                $codespace.owner.login | Should -Be $script:OwnerName
            }
        }
    }

    Context 'When getting a codespace for a specified codespace name' {
        BeforeAll {
            $codespaces = Get-GitHubCodespace
            $codespace = Get-GitHubCodespace -CodespaceName $codespaces[0].name
        }

        It 'Should return objects of the correct type' {
            $codespace.PSObject.TypeNames[0] | Should -Be 'GitHub.Codespace'
        }

        It 'Should return the correct properties' {
            $codespace.owner.login | Should -Be $script:OwnerName
        }
    }

    Context 'When specifiying the Uri parameter' {
        BeforeAll {
            $codespace = Get-GitHubCodespace -Uri $repo.RepositoryUrl
        }

        It 'Should return objects of the correct type' {
            $codespace.PSObject.TypeNames[0] | Should -Be 'GitHub.Codespace'
        }

        It 'Should return the correct properties' {
            $codespace.owner.login | Should -Be $script:OwnerName
            $codespace.repository.name | Should -Be $repo.name
        }
    }

    Context "When specifiying the Uri parameter from the pipeline" {
        BeforeAll {
            $codespace = $repo | Get-GitHubCodespace
        }

        It 'Should return objects of the correct type' {
            $codespace.PSObject.TypeNames[0] | Should -Be 'GitHub.Codespace'
        }

        It 'Should return the correct properties' {
            $codespace.repository.name | Should -Be $repo.name
        }
    }
}

Describe 'GitHubCodespaces\Start-GitHubCodespace' {
    BeforeAll {
        # Suppress HTTP 202 warning for codespace creation
        $WarningPreference = 'SilentlyContinue'

        $newGitHubCodespaceParms = @{
            OwnerName = $script:organizationName
            RepositoryName = $defaultRepositoryName
        }
        $null = New-GitHubCodespace @newGitHubCodespaceParms
        Start-Sleep -Seconds 3
    }

    Context 'When starting a codespace for the authenticated user' {
        BeforeAll {
            $codespace = Get-GitHubCodespace @newGitHubCodespaceParms
        }

        It 'Should not throw' {
            # Also asserts pipeline input
            { $codespace | Start-GitHubCodespace } | Should -Not -Throw
        }

        It 'Should become Available' {
            # Also asserts Wait and PassThru
            $result = $codespace | Start-GitHubCodespace -Wait -PassThru
            $result.State | Should -Be 'Available'
        }
    }
}

Describe 'GitHubCodespaces\Stop-GitHubCodespace' {
    BeforeAll {
        # Suppress HTTP 202 warning for codespace creation
        $WarningPreference = 'SilentlyContinue'

        $newGitHubCodespaceParms = @{
            OwnerName = $script:organizationName
            RepositoryName = $defaultRepositoryName
        }
        $null = New-GitHubCodespace @newGitHubCodespaceParms
        Start-Sleep -Seconds 3
    }

    Context 'When stopping a codespace for the authenticated user' {
        BeforeAll {
            $codespace = Get-GitHubCodespace @newGitHubCodespaceParms
        }

        It 'Should not throw' {
            # Also asserts pipeline input
            { $codespace | Stop-GitHubCodespace } | Should -Not -Throw
        }

        It 'Should become Shutdown' {
            # Also asserts Wait and PassThru
            $result = $codespace | Stop-GitHubCodespace -Wait -PassThru
            $result.State | Should -Be 'Shutdown'
        }
    }
}

AfterAll {
    if (Get-Variable -Name repo -ErrorAction SilentlyContinue)
    {
        # Should delete any corresponding codespaces along with it
        $repo | Remove-GitHubRepository -Confirm:$false
    }

    if (Test-Path -Path $script:originalConfigFile -PathType Leaf)
    {
        # Restore the user's configuration to its pre-test state
        Restore-GitHubConfiguration -Path $script:originalConfigFile
        $script:originalConfigFile = $null
    }
}
