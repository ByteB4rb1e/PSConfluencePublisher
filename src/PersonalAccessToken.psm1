#!/usr/bin/env pwsh
<#
    .SYNOPSIS
        Utilities for working with Confluence Personal Access Tokens

    .DESCRIPTION

        

    .EXAMPLE

        Register-PersonalAccessToken `
            -Host 'confluence.contoso.com' `
            -Token '123456789123456789'

        Get-PersonalAccessToken -Host 'confluence.contoso.com'
#>
$ErrorActionPreference = "Stop"


# session storage of Confluence personal access tokens, scoped to this nested
# module
$script:PATS = @{}


function Initialize-PersonalAccessTokenStore
{
    <#
        .SYNOPSIS
            Initialize the store within this script's scope.

        .EXAMPLE
            Initialize-PersonalAccessTokenStore
    #>
    Process
    {
        $script:PATS = @{}
    }
}


function Register-PersonalAccessToken
{
    <#
        .SYNOPSIS
            Register a Confluence Personal Access Token (PAT)

        .DESCRIPTION
            The PAT is stored in the pseudo-local ``script`` scope as a 
            SecureString. Implementors of functions accessing PATs MUST stall 
            conversion to plain text string until the string is actually needed

        .EXAMPLE
            Register-PersonalAccessToken confluence.contoso.com 0123456789
    #>
    [CmdletBinding()]
    
    Param(
        [Parameter(Mandatory, Position = 0)] [string] $Host,
        [Parameter(Mandatory, Position = 1)] [string] $Token
    )

    Process
    {
        if ($script:PATS[$Host])
        {
            Write-Debug "PAT for '$Host' already registered, overwriting."
        }

        $script:PATS[$Host] = ConvertTo-SecureString $Token -AsPlainText -Force
    }
}


function Get-PersonalAccessToken
{
    <#
        .SYNOPSIS
            Get a Confluence Personal Access Token (PAT) registered in this
            script scope.

        .EXAMPLE
            Get-PersonalAccessToken confluence.contoso.com
    #>
    Param(
        # Confluence instance hostname
        [Parameter(Mandatory, Position = 0)] [string] $Host
    )

    Process
    {
        if (-Not $PATS[$Host])
        {
            throw "No personal access token for host '$Host' registered. " +
            "Hint: Call ``Register-PersonalAccessToken``"
        }

        $([Net.NetworkCredential]::new('', $script:PATS[$Host]).Password)
    }
}
