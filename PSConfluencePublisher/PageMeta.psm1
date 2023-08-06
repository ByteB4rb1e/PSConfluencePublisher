#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


function Get-PageMetaCache
{
    <#
        .SYNOPSIS
            Get a locally indexed/cached Confluence page id

        .EXAMPLE
            Get-PageMetaCache `
                 -Title 'Page Title' `
                 -Manifest @() `
                 -Index @{}

        .NOTES
            To test or not to test, that is the question... Since the
            `Test-JSON` cmdlet requires serialized JSON, but we are working with
            the deserialized Hashtable, it's too computationally intense to
            always test the input upon every call. We therefore only make sure, 
            that correct data is written to the filesystem. For the rest, each 
            function is responsible for themself (learned that that's a valid 
            reflexive pronoun today 🤓).

            This function is lucky to get this note, because it's at the top 💯. 
            Of course this applies to every function.
    #>
    Param(
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [Array] $Manifest,
        [Parameter()] [Collections.Hashtable] $Index
    )

    Process
    {
        If ($Index -And $Manifest.Count -gt 0 -And $Manifest[$Index.$Title])
        {
            $Manifest[$Index.$Title]
        }

        Else
        {
            For ($i = 0; $i -lt $Manifest.Count; $i += 1)
            {
                If ($Manifest[$i].Title -eq $Title)
                {
                    $Manifest[$i]

                    break
                }
            }
        }
    }
}


function Get-PageMeta
{
    <#
        .SYNOPSIS
            Get a Confluence page id

        .DESCRIPTION
            First, tries to retrieve from local page id index (cache) through 
            the local alias. If no cache hit, then polls the Confluence 
            instance host for the id by providing a space key and page title.

        .EXAMPLE
            Get-PageMeta `
                 -Host 'confluence.contoso.com' `
                 -Title 'Testitest' `
                 -Space 'TIARA' `
                 -CacheIndexFile 'confluence-page-cache.json'
    #>
    Param(
        [Parameter(Mandatory)] [string] $Host,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Space,
        [Parameter(Mandatory)] [Array] $Manifest,
        [Parameter()] [Collections.Hashtable] $Index
    )

    Begin
    {
         $pageMeta = Get-PageMetaCache `
             -Title $Title `
             -Manifest $Manifest `
             -Index $Index
    }

    Process
    {
        If ($pageMeta -And $pageMeta.PageId)
        {
            $pageMeta

            return
        }

        $escapedTitle = [Uri]::EscapeDataString($Title)

        #TODO: move this to a separate function
        $query = "title=${escapedTitle}&spaceKey=${Space}&expand=history"

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content?$query" `
            -Method 'Get' `
            -Headers @{
                'Authorization' = "Bearer $(Get-PersonalAccessToken $Host)"
            } `
            -OutVariable response | Out-Null

        $results = ($response.Content | ConvertFrom-JSON).results

        if ($results.Count -gt 1)
        {
            throw "more than one result for query: $query"
        }

        elseif ($results.Count -eq 1) 
        {
            Update-PageMeta `
                -PageId $results[0].id `
                -Version ($results[0]._expandable | Select -ExpandProperty 'version') `
                -Title $Title `
                -Manifest $Manifest
        }
    }
}


function Update-PageMeta
{
    <#
        .SYNOPSIS
            Register a Confluence page's metadata in the local cache

        .DESCRIPTION
            Synchronizes the locally cached page metadata (in manifest) with the
            data stored by the Confluence instance. Therefore it is required to
            supply a page id, since this is the reference linking the locally
            cached page to a published instance of a page.

        .EXAMPLE
            Update-PageMeta `
                -Title 'foobar' `
                -PageId 'pageId' `
                -Version 9001 `
                -AncestorTitle 'ancestorTitle' `
                -Hash 'hash' `
                -Manifest $mockManifest
    #>
    Param(
        [Parameter(Mandatory)] [String] $Title,
        [Parameter(Mandatory)] [String] $PageId,
        [Parameter()] [Int] $Version,
        [Parameter()] [String] $AncestorTitle,
        [Parameter()] [String] $Hash,
        [Parameter(Mandatory)] [Array] $Manifest,
        [Parameter()] [Collections.Hashtable] $Index
    )

    Process
    {
        $pageMeta = Get-PageMetaCache `
                        -Title $Title `
                        -Manifest $Manifest `
                        -Index $Index

        If (-Not $pageMeta)
        {
            throw "page titled `$Title` not indexed in Manifest."
        }

        $pageMeta.PageId = $PageId

        If ($Version)
        {
            $pageMeta.Version = $Version
        }

        If ($AncestorTitle)
        {
            $pageMeta.AncestorTitle = $AncestorTitle
        }

        # if content didn't update, hash stays the same
        If ($Hash)
        {
            $pageMeta.Hash = $Hash
        }

        Write-Debug "register: $Title -> $PageId"

        $pageMeta
    }
}

