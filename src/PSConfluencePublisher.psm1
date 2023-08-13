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


function Initialize-Manifest
{
    <#

    #>
    Param(
        # path of manifest to load
        [Parameter(Mandatory)] [String] $Path
    )

    Begin
    {
        $literalPath = Resolve-Path -Path $Path
    }

    Process
    {
        Write-Debug 'loading manifest...'

        $manifest = Get-Manifest $literalPath

        Write-Debug 'creating pages manifest index...'

        $pagesManifestIndex = New-PagesManifestIndex -Manifest $manifest.Pages

        Write-Debug 'creating ancestral page generation cache...'

        $ancestralGenerationCache = New-AncestralPageGenerationCache `
                                        -Manifest $manifest.Pages `
                                        -Index $pagesManifestIndex

        Write-Debug 'sorting pages manifest...'

        Optimize-PagesManifest `
            -Manifest $manifest.Pages `
            -Lo 0 `
            -Hi ($manifest.Pages.Count - 1) `
            -GenerationCache $ancestralGenerationCache | Out-Null
    }

    End
    {
        @{
            'Path' = $literalPath
            'Manifest' = $manifest
            'Index' = @{
                'Pages' = New-PagesManifestIndex `
                              -Manifest $manifest.Pages
                'Attachments' = New-AttachmentsManifestIndex `
                                    -Manifest $manifest.Attachments
            }
        } 
    }
}


function Initialize-Connection
{
    Param(
        [Parameter(Mandatory)] [String]$Host,
        [Parameter(Mandatory)] [String]$Space,
        [Parameter(Mandatory)] [String]$PersonalAccessToken
    )

    Process
    {
        Register-PersonalAccessToken `
            -Host $Host `
            -Token $PersonalAccessToken | Out-Null

        Test-Connection -Host $Host | Out-Null
    }

    End
    {
        @{
            'Host' = $Host
            'Space' = $Space
        }
    }
}


function Publish-Pages
{
    Param(
        # connection object created through Initialize-Connection
        [Parameter(Mandatory)] [Collections.Hashtable]$Connection,
        # manifest object created through Initialize-Manifest
        [Parameter(Mandatory)] [PSCustomObject]$Manifest,
        # 
        [Parameter()] [Switch]$Strict,
        # 
        [Parameter()] [Switch]$Force,
        # title of page to be published
        [Parameter()] [String]$Title
    )

    Process
    {
         $Manifest.Manifest.Pages | Publish-Page `
             -Host $Connection.Host `
             -Space $Connection.Space `
             -Title $Title `
             -Index $Manifest.Index.Pages `
             -Strict:$Strict `
             -Force:$Force | Out-Null
    }
}
