#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


function Test-Connection
{
    <#
        .SYNOPSIS
            Test the connectivity to a Confluence instance.

        .DESCRIPTION
            Just making an arbitrary authenticated HTTP request and making sure 
            that we're getting a 2xx status code back. This way we make sure 
            that network connectivity is fine, and that the PAT is valid.
    
            It is required to register a PAT through 
            ``Register-PersonalAccessToken`` beforehand.

        .EXAMPLE
            Test-Connection confluence.contoso.com
    #>
    Param(
        [Parameter(Mandatory, Position = 0)] [string] $Host
    )

    Process
    {
        # Screw Invoke-RestMethod, how am i supposed to get a non 4xx status 
        # code? Catch a non-existent exception 🤷‍♀️????
        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/user/current" `
            -Method 'Get' `
            -Headers @{
                'Authorization' = "Bearer $(Get-PersonalAccessToken $Host)"
            } `
            -OutVariable response

        if(($response.Content | ConvertFrom-JSON).type -ne "known")
        {
            throw "personal access token for host '$Host' does not " + 
                  "authenticate."
        }

        if ($response.StatusCode -eq 200)
        {
            Write-Host "Verified connectivity ($Host)."
        }
        else
        {
            throw "received status code other than 200 " +
                  "($($response.StatusCode))"
        }
    }
}
