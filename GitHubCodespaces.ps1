# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubCodespaceTypeName = 'GitHub.Codespace'
}.GetEnumerator() | ForEach-Object {
    Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
}

filter Get-GitHubCodespace
{
    <#
    .SYNOPSIS
        Retrieves information about a Codespace or list of codespaces on GitHub.

    .DESCRIPTION
        Retrieves information about a Codespace or list of codespaces on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OwnerName
        Owner of the Codespace.
        If not supplied here, the DefaultOwnerName configuration property value will be used.

    .PARAMETER RepositoryName
        Name of the repository.
        If not supplied here, the DefaultRepositoryName configuration property value will be used.

    .PARAMETER Uri
        Uri for the Codespace.
        The OwnerName and CodespaceName will be extracted from here instead of needing to provide
        them individually.

    .PARAMETER OrganizationName
        The name of the organization to retrieve the codespaces for.

    .PARAMETER UserName
        The handle for the GitHub user account.

    .PARAMETER CodespaceName
        Name of the Codespace.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Codespace
        GitHub.Project
        GitHub.Repository
        GitHub.User

    .OUTPUTS
        GitHub.Codespace

    .EXAMPLE
        Get-GitHubCodespace

        Gets all codespaces for the current authenticated user.

    .EXAMPLE
        Get-GitHubCodespace -OwnerName octocat

        Gets all of the codespaces for the user octocat

    .EXAMPLE
        Get-GitHubUser -UserName octocat | Get-GitHubCodespace

        Gets all of the codespaces for the user octocat

    .EXAMPLE
        Get-GitHubCodespace -Uri https://github.com/microsoft/PowerShellForGitHub

        Gets information about the microsoft/PowerShellForGitHub Codespace.

    .EXAMPLE
        $repo | Get-GitHubCodespace

        You can pipe in a previous Codespace to get its refreshed information.

    .EXAMPLE
        Get-GitHubCodespace -OrganizationName PowerShell

        Gets all of the codespaces in the PowerShell organization.
#>
    [CmdletBinding(DefaultParameterSetName = 'AuthenticatedUser')]
    [OutputType({ $script:GitHubCodespaceTypeName })]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification = "The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Repository')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Repository')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Organization')]
        [string] $OrganizationName,

        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Organization')]
        [ValidateNotNullOrEmpty()]
        [String] $UserName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'CodespaceName')]
        [string] $CodespaceName,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{
        'UsageType' = $PSCmdlet.ParameterSetName
    }

    $uriFragment = [String]::Empty
    $description = [String]::Empty
    switch ($PSCmdlet.ParameterSetName)
    {
        'AuthenticatedUser'
        {
            # /user/codespaces
            $uriFragment = 'user/codespaces'
            $description = 'Getting codespaces for current authenticated user'

            break
        }

        'CodespaceName'
        {
            $telemetryProperties['CodespaceName'] = Get-PiiSafeString -PlainText $CodespaceName

            $uriFragment = "user/codespaces/$CodespaceName"
            $description = "Getting user/codespaces/$CodespaceName"

            break
        }

        'Organization'
        {
            # /orgs/{org}/codespaces
            # /orgs/{org}/members/{username}/codespaces

            $telemetryProperties['OrganizationName'] = Get-PiiSafeString -PlainText $OrganizationName
            if ([string]::IsNullOrWhiteSpace($UserName))
            {
                $uriFragment = "orgs/$OrganizationName/codespaces"
                $description = "Getting codespaces for $OrganizationName"
            }
            else
            {
                $telemetryProperties['UserName'] = Get-PiiSafeString -PlainText $UserName
                $uriFragment = "orgs/$OrganizationName/members/$UserName/codespaces"
                $description = "Getting codespaces for $OrganizationName"
            }

            break
        }

        'Repository'
        {
            $elements = Resolve-RepositoryElements
            $OwnerName = $elements.ownerName
            $RepositoryName = $elements.repositoryName

            $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
            $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName

            $uriFragment = "repos/$OwnerName/$RepositoryName/codespaces"
            $description = "Getting $OwnerName/$RepositoryName/codespaces"

            break
        }

        'Uri'
        {
            $elements = Resolve-RepositoryElements
            $OwnerName = $elements.ownerName
            $RepositoryName = $elements.repositoryName

            $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
            $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName

            $uriFragment = "repos/$OwnerName/$RepositoryName/codespaces"
            $description = "Getting $OwnerName/$RepositoryName/codespaces"

            break
        }
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AcceptHeader' = "$script:nebulaAcceptHeader,$script:baptisteAcceptHeader,$script:mercyAcceptHeader"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = Invoke-GHRestMethodMultipleResult @params
    if ($result.codespaces)
    {
        $result = $result.codespaces
    }

    return ($result | Add-GitHubCodespaceAdditionalProperties)
}

function Start-GitHubCodespace
{
    <#
    .SYNOPSIS
        Start a user's codespace.

    .DESCRIPTION
        You must authenticate using an access token with the codespace scope to use this endpoint.

        GitHub Apps must have write access to the codespaces_lifecycle_admin repository permission to use this endpoint.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER CodespaceName
        The name of the codespace.

    .PARAMETER Wait
        If present will wait for the codespace to start.

    .PARAMETER PassThru
        Returns the updated GitHub Issue.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Codespace

    .OUTPUTS
        GitHub.Codespace

    .EXAMPLE
        Start-GitHubCodespace -Name vercellone-effective-goggles-qrv997q6j9929jx8

    .LINK
        https://docs.github.com/en/rest/codespaces/codespaces?apiVersion=2022-11-28#start-a-codespace-for-the-authenticated-user
#>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Low')]
    [OutputType({ $script:GitHubCodespaceTypeName })]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification = "PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string] $CodespaceName,

        [switch] $Wait,

        [switch] $PassThru,

        [string] $AccessToken
    )

    process
    {
        Write-InvocationLog

        $telemetryProperties = @{
            'CodespaceName' = Get-PiiSafeString -PlainText $CodespaceName
        }

        $params = @{
            'UriFragment' = "user/codespaces/$CodespaceName/start"
            'Method' = 'POST'
            'Description' = "Start Codespace $CodespaceName"
            'AccessToken' = $AccessToken
            'AcceptHeader' = $script:symmetraAcceptHeader
            'TelemetryEventName' = $MyInvocation.MyCommand.Name
            'TelemetryProperties' = $telemetryProperties
        }

        if (-not $PSCmdlet.ShouldProcess($CodespaceName, "Start Codespace $CodespaceName"))
        {
            return
        }

        $result = (Invoke-GHRestMethod @params | Add-GitHubCodespaceAdditionalProperties)

        if ($Wait.IsPresent)
        {
            $waitParams = @{
                'CodespaceName' = $CodespaceName
                'AccessToken' = $AccessToken
            }

            $result = Wait-GitHubCodespaceAction @waitParams
        }

        if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        {
            return $result
        }
    }
}

function Stop-GitHubCodespace
{
    <#
    .SYNOPSIS
        Stop a user's codespace.

    .DESCRIPTION
        You must authenticate using an access token with the codespace scope to use this endpoint.

        GitHub Apps must have write access to the codespaces_lifecycle_admin repository permission to use this endpoint.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER CodespaceName
        The name of the codespace.

    .PARAMETER Wait
        If present will wait for the codespace to stop.

    .PARAMETER PassThru
        Returns the updated GitHub Issue.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Codespace

    .OUTPUTS
        GitHub.Codespace

    .EXAMPLE
        Stop-GitHubCodespace -Name vercellone-effective-goggles-qrv997q6j9929jx8

    .LINK
        https://docs.github.com/en/rest/codespaces/codespaces?apiVersion=2022-11-28#stop-a-codespace-for-the-authenticated-user
#>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Low')]
    [OutputType({ $script:GitHubCodespaceTypeName })]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification = "PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string] $CodespaceName,

        [switch] $Wait,

        [switch] $PassThru,

        [string] $AccessToken
    )

    process
    {
        Write-InvocationLog

        $telemetryProperties = @{
            'CodespaceName' = Get-PiiSafeString -PlainText $CodespaceName
        }

        $params = @{
            'UriFragment' = "user/codespaces/$CodespaceName/stop"
            'Method' = 'POST'
            'Description' = "Stop Codespace $CodespaceName"
            'AccessToken' = $AccessToken
            'AcceptHeader' = $script:symmetraAcceptHeader
            'TelemetryEventName' = $MyInvocation.MyCommand.Name
            'TelemetryProperties' = $telemetryProperties
        }

        if (-not $PSCmdlet.ShouldProcess($CodespaceName, "Stop Codespace $CodespaceName"))
        {
            return
        }

        $result = (Invoke-GHRestMethod @params | Add-GitHubCodespaceAdditionalProperties)

        if ($Wait.IsPresent)
        {
            $waitParams = @{
                'CodespaceName' = $CodespaceName
                'AccessToken' = $AccessToken
            }

            $result = Wait-GitHubCodespaceAction @waitParams
        }

        if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        {
            return $result
        }
    }
}

function Wait-GitHubCodespaceAction
{
    <#
    .SYNOPSIS
        Wait for a Codespace start or stop action.

    .PARAMETER CodespaceName
        The name of the codespace.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Codespace

    .OUTPUTS
        GitHub.Codespace

    .EXAMPLE
        Wait-GitHubCodespace -Name vercellone-effective-goggles-qrv997q6j9929jx8
#>
    [CmdletBinding()]
    [OutputType({ $script:GitHubCodespaceTypeName })]
    param(
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string] $CodespaceName,

        [string] $AccessToken
    )

    begin
    {
        # 2s minimum
        $sleepSeconds = $(Get-GitHubConfiguration -Name 'StateChangeDelaySeconds')
        if ($sleepSeconds -eq 0)
        {
            $sleepSeconds = 2
        }
    }

    process
    {
        Write-InvocationLog

        do
        {
            Start-Sleep -Seconds $sleepSeconds
            $codespace = (Get-GitHubCodespace @PSBoundParameters)
        } until($codespace.state -notmatch 'Queued|ing')

        return $codespace
    }
}

filter Add-GitHubCodespaceAdditionalProperties
{
    <#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Repository objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .PARAMETER OwnerName
        Owner of the repository.  This information might be obtainable from InputObject, so this
        is optional based on what InputObject contains.

    .PARAMETER RepositoryName
        Name of the repository.  This information might be obtainable from InputObject, so this
        is optional based on what InputObject contains.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Repository
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Internal helper that is definitely adding more than one property.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [PSCustomObject[]] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubCodespaceTypeName
    )
    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            if ($item.name)
            {
                Add-Member -InputObject $item -Name 'CodespaceUrl' -Value "user/codespaces/$($item.name)" -MemberType NoteProperty -Force
                Add-Member -InputObject $item -Name 'CodespaceName' -Value $item.name -MemberType NoteProperty -Force
            }

            if ($null -ne $item.owner)
            {
                $null = Add-GitHubUserAdditionalProperties -InputObject $item.owner
            }

            if ($null -ne $item.organization)
            {
                $null = Add-GitHubOrganizationAdditionalProperties -InputObject $item.organization
            }

            if ($null -ne $item.repository)
            {
                $null = Add-GitHubRepositoryAdditionalProperties -InputObject $item.repository
            }
        }

        Write-Output $item
    }
}
