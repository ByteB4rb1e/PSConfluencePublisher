#!/usr/bin/env pwsh
<#
    .SYNOPSIS
        PowerShell Publisher for sphinxcontrib.confluencebuilder

    .DESCRIPTION

        - support for ancestral pages and containered attachments
        - creates new pages if they don't exist
        - updates existing pages and attachments if checksum mismatches

    .EXAMPLE

        Import-Module (Join-Path 'vendor' 'tiara.rodney' 
                                 'PSConfluencePublisher'
                                 'PSConfluencePublisher'
                                 'PSConfluencePublisher.psd1')

        Register-PersonalAccessToken `
            -Host 'confluence.contoso.com' `
            -Token '123456789123456789'

        Test-Connection confluence.contoso.com

        Publish-All `
            -Url 'https://confluence.contoso.com/display/TIARA/Testitest' `
            -DumpIndex build/docs/confluence.out/data.json

    .NOTES
        - tested with PowerShell Core (PSVersion 7.3.6)
        - tested with PowerShell Desktop (PSVersion 5.1.19041.3031)
#>
$ErrorActionPreference = "Stop"


