#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


function Get-CachedPageMeta
{
    <#
        .SYNOPSIS
            Get a locally indexed/cached Confluence page id

        .EXAMPLE
            Get-CachedPageMeta `
                 -Title 'Page Title' `
                 -Manifest @{...}

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
        [Parameter(Mandatory)] [Collections.Hashtable] $Manifest
    )

    Process
    {
        #it's fine this fails, if no `Pages` property is provided, since the
        #object (according to the schema) would be invalid anyway.
        $pages = $Manifest | Select -ExpandProperty 'Pages'

        try
        {
            $pageMeta = $pages | Select -ExpandProperty $Title

            Write-Debug "page id cache hit: $Title -> $($pageMeta.PageId)"

            $pageMeta
        }

        catch
        {
            Write-Debug "page id cache miss: $Title"

            $null
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
        [Parameter(Mandatory)] [Collections.Hashtable] $Manifest
    )

    Process
    {
        if ($Title)
        {
            $cachedPageMeta = Get-CachedPageMeta `
                -Title $Title `
                -Manifest $Manifest
        }

        if ($cachedPageMeta)
        {
            return $cachedPageMeta
        }

        $escapedTitle = [uri]::EscapeDataString($Title)

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

        .EXAMPLE
            Add-ConfluencePage 
                -Host 'confluence.contoso.com' `
                -Space 'TIARA' `
                -Title 'Testitest' `
                -Content @{}
    #>
    Param(
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $PageId,
        [Parameter()]          [int] $Version,
        [Parameter()]          [string] $AncestorTitle,
        [Parameter()]          [string] $Hash,
        [Parameter(Mandatory)] [Collections.Hashtable] $Manifest
    )

    Process
    {
        $metaPages = $Manifest.Pages

        if ((-Not $metaPages) -Or (-Not $metaPages.$Title))
        {
            throw "page titled `$Title` not indexed in Manifest."
        }

        $meta = $metaPages.$Title

        $meta['PageId'] = $PageId

        if ($Version)
        {
            $meta['Version'] = $Version
        }

        if ($AncestorTitle)
        {
            $meta['AncestorTitle'] = $AncestorTitle
        }

        # if content didn't update, hash stays the same
        if ($Hash)
        {
            $meta['Hash'] = $Hash
        }

        Write-Debug "register: $Title -> $PageId"
    }
}


function New-Page
{
    <#
        .SYNOPSIS
            Add a confluence page

        .DESCRIPTION

        .EXAMPLE
            Add-ConfluencePage `
                -Host 'confluence.contoso.com' `
                -Space 'TIARA' `
                -Title 'Testitest' `
                -Content @{}
    #>
    Param(
        # confluence instance hostname
        [Parameter(Mandatory)] [string] $Host,
        # name of the Confluence space to publish to
        [Parameter(Mandatory)] [string] $Space,
        # title of page to be published
        [Parameter(Mandatory)] [string] $Title,
        # manifest
        [Parameter(Mandatory)] [Collections.Hashtable] $Manifest
    )

    Process
    {
        $meta = $Manifest.Pages.$Title

        if (-Not $meta.Ref)
        {
            throw "no reference to local content for page `$Title`."
        }

        $content = Get-Content -Path $meta.Ref

        $transportBody = @{
            'type' = 'page'
            'title' = $Title
            'space' = @{
                'key' = $Space
            }
            'body' = @{
                'storage' = @{
                    'value' = $content
                    'representation' = 'storage'
                }
            }
        } | ConvertTo-JSON

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content" `
            -Method 'Post' `
            -Headers @{
                'Authorization' = "Bearer $(Get-PersonalAccessToken $Host)"
            } `
            -ContentType "application/json" `
            -Body $transportBody `
            -OutVariable rawResponse | Out-Null
    }

    End
    {
        $response = ($rawResponse.Content | ConvertFrom-JSON)

        $meta.PageId = $response.Id

        $meta.Version = $response.version | Select -ExpandProperty 'number'

        $meta
    }
}


function Update-Page
{
    <#
        .SYNOPSIS
            Add a confluence page

        .DESCRIPTION

        .EXAMPLE
            Update-ConfluencePage 
                -Host 'confluence.contoso.com' `
                -Space 'TIARA' `
                -Title 'Testitest' `
                -Manifest @{}
    #>
    Param(
        [Parameter(Mandatory)] [string] $Host,
        # The name of the Confluence space to publish to
        [Parameter(Mandatory)] [string] $Space,
        # title of page to be published
        [Parameter(Mandatory)] [string] $Title,
        # manifest
        [Parameter(Mandatory)] [Collections.Hashtable] $Meta
    )

    Process
    {
        $meta = $Manifest.Pages.$Title

        if (-Not $meta.Ref)
        {
            throw "no reference to local content for page '$Title'."
        }

        if (-Not $meta.Id)
        {
            throw "no id for page '$Title'."
        }

        $content = Get-Content -Path $meta.Ref

        #FIXME: create a stream instead of reading from filesystem again
        $hash = (Get-FileHash -Path $meta.Ref -Algorithm SHA256).Hash

        if ($hash -eq $meta.Hash)
        {
            Write-Host "content unchanged, skipping: '$Title'"

            # yep, this is funny... This behaves like a return statement, because
            # a cmdlet, treats the input as an array of inputs. We keep it that
            # way so that all functions can properly act upon pipes. See
            # additional information on 'Process' blocks.
            continue
        }

        # we're not updating this in place, so that we don't have to reset the
        # value opon failure
        $version = $meta.Version + 1

        $transportBody = @{
            'id' = $PageId
            'type' = 'page'
            'title' = $Title
            'space' = @{
                'key' = $Space
            }
            'body' = @{
                'storage' = @{
                    'value' = $Content
                    'representation' = 'storage'
                }
            }
            'version' = @{
                'number' = $version
            }
        } | ConvertTo-JSON

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content/$PageId" `
            -Method 'Put' `
            -Headers @{
                'Authorization' = "Bearer $(Get-PersonalAccessToken $Host)"
            } `
            -ContentType "application/json" `
            -Body $transportBody `
            -OutVariable rawResponse | Out-Null
    }

    End
    {
        $response = ($rawResponse.Content | ConvertFrom-JSON)

        $meta.Version = $response.version | Select -ExpandProperty 'number'

        $meta.Hash = $hash

        $meta
    }
}


function Publish-Page
{
    Param(
        # title of the page (used for manifest lookup)
        [Parameter(Mandatory)] [string] $Title,
        # hostname of Confluence instance
        [Parameter(Mandatory)] [string] $Host,
        # name of Confluence space
        [Parameter(Mandatory)] [string] $Space,
        # manifest object
        [Parameter(Mandatory, ValueFromPipeline)] [PSObject] $Meta
    )

    Process
    {
        ForEach($meta in $Meta)
        {
            $meta = Get-PageMeta `
                            -Host $hostname `
                            -Space $spaceName `
                            -Title $Title `
                            -Manifest $Manifest

            if ($meta.AncestorTitle)
            {
                $ancestorPageMeta = Get-PageMeta `
                                        -Host $hostname `
                                        -Space $spaceName `
                                        -Title $pageMeta.AncestorTitle `
                                        -Manifest $Manifest

                if (-Not ($ancestorPageMeta -Or $ancestorPageMeta.PageId))
                {
                    Write-Host "ancestor, not published, skipping: $Title"

                    continue
                }
            }

            if (-Not $pageId)
            {
                Write-Host ("create ${_}: $prettyName")

                try {
                    New-Page `
                        -Host $hostname `
                        -Space $spaceName `
                        -Title $Title `
                        -Manifest $Manifest
                }

                catch
                {
                    Write-Host "error for '$Title', skipping: $_"

                    continue
                }
            }

            else
            {
                Write-Host ("update ${_} (${pageId}): $prettyName")

                try
                {
                    Update-Page `
                        -Host $hostname `
                        -Space $Space `
                        -Title $Title `
                        -Manifest $Manifest
                }

                catch
                {
                    Write-Host "error for '$Title', skipping: $_"

                    continue
                }
            }

            }

    }
}
