#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


function Get-CachedPageMeta
{
    <#
        .SYNOPSIS
            Get a locally indexed/cached Confluence page id

        .EXAMPLE
            Get-CachedPageMeta `
                 -Title 'd231cc3422bfdf96.xml' `
                 -CacheIndexFile 'confluence-page-cache.json'
    #>
    Param(
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $CacheIndexFile
    )

    Process
    {
        try
        {
            $raw = Get-Content $CacheIndexFile
        }

        catch
        { 
            $raw = "{}"
        }

        $data = $raw | ConvertFrom-JSON

        try
        {
            $pageMeta = $data | Select -ExpandProperty $Title

            $pageMeta

            Write-Debug "page id cache hit: $Title -> $($pageMeta.PageId)"
        }

        catch
        {
            $null

            Write-Debug "page id cache miss: $Title"
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
           Get-PageMeta
                -Host 'confluence.contoso.com' `
                -Title 'Testitest' `
                -Space 'TIARA' `
                -CacheIndexFile 'confluence-page-cache.json'
    #>
    Param(
        [Parameter(Mandatory)] [string] $Host,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Space,
        [Parameter(Mandatory)] [string] $CacheIndexFile
    )

    Process
    {
        if ($Title)
        {
            $cachedPageMeta = Get-CachedPageMeta `
                -Title $Title `
                -CacheIndexFile $CacheIndexFile
        }

        if ($cachedPageMeta)
        {
            return $cachedPageMeta
        }

        $escapedTitle = [uri]::EscapeDataString($Title)

        $query = "title=${escapedTitle}&spaceKey=${Space}&expand=history"

        Assert-PersonalAccessToken $Host

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content?$query" `
            -Method 'Get' `
            -Headers @{
                'Authorization' = "Bearer $([System.Net.NetworkCredential]::new('', $script:PATS[$Host_]).Password)"
            } `
            -OutVariable response

        $results = ($response.Content | ConvertFrom-JSON).results

        if ($results.Count -gt 1)
        {
            throw "more than one result for query: $query"
        }
        elseif ($results.Count -eq 1) 
        {
            Register-PageMeta `
                -PageId $results[0].id `
                -Version ($results[0]._expandable | Select -ExpandProperty 'version') `
                -Title $Title `
                -CacheIndexFile $CacheIndexFile
        }
    }
}


function Register-PageMeta
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
        [Parameter(Mandatory)] [string] $PageId,
        [Parameter()]          [int]    $Version = 0,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter()]          [string] $ContentHash = '',
        [Parameter(Mandatory)] [string] $CacheIndexFile
    )

    Process
    {
        try
        {
            $raw = Get-Content $CacheIndexFile
        }

        catch
        { 
            $raw = "{}"
        }

        $data = $raw | ConvertFrom-JSON

        $data | Add-Member -Name $Title `
            -Value @{
                'PageId' = $PageId
                'Version' = $Version
                'ContentHash' = $ContentHash
            } `
            -MemberType NoteProperty `
            -Force

        Set-Content -Path $CacheIndexFile -Value ($data | ConvertTo-JSON)

        Write-Debug "indexed page id: $Title -> $PageId"
    }
}


function New-Page
{
    <#
        .SYNOPSIS
            Add a confluence page

        .DESCRIPTION

        .EXAMPLE
            Add-ConfluencePage 
                -Host 'confluence.contoso.com' `
                -Space 'TIARA' `
                -Title 'Testitest' `
                -Content @{}
    #>
    Param(
        [Parameter(Mandatory)] [string] $Host,
        # The name of the Confluence space to publish to
        [Parameter(Mandatory)] [string] $Space,
        # title of page to be published
        [Parameter(Mandatory)] [string] $Title,
        # content of page
        [Parameter(Mandatory)] [string] $Content,
        # parent page id
        [Parameter()] [string] $Ancestor
    )

    Process
    {
        Assert-PersonalAccessToken $Host

        $transportBody = @{
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
        } | ConvertTo-JSON

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content" `
            -Method 'Post' `
            -Headers @{
                'Authorization' = "Bearer $([System.Net.NetworkCredential]::new('', $script:PATS[$Host_]).Password)"
            } `
            -ContentType "application/json" `
            -Body $transportBody `
            -OutVariable rawResponse | Out-Null
    }

    End
    {
        $response = ($rawResponse.Content | ConvertFrom-JSON)

        @{
            'PageId' = $response.Id
            'Version' = $response.version | Select -ExpandProperty 'number'
        }
    }
}


function Update-Page
{
    <#
        .SYNOPSIS
            Add a confluence page

        .DESCRIPTION

        .EXAMPLE
            Add-ConfluencePage 
                -Host 'confluence.contoso.com' `
                -Space 'TIARA' `
                -Title 'Testitest' `
                -Content @{}
    #>
    Param(
        [Parameter(Mandatory)] [string] $Host,
        # The page id of an existing page
        [Parameter(Mandatory)] [string] $PageId,
        # The name of the Confluence space to publish to
        [Parameter(Mandatory)] [string] $Space,
        # title of page to be published
        [Parameter(Mandatory)] [string] $Title,
        # version of content
        [Parameter(Mandatory)] [int] $Version,
        # content of page
        [Parameter(Mandatory)] [string] $Content,
        # parent page id
        [Parameter()] [string] $Ancestor
    )

    Process
    {
        Assert-PersonalAccessToken $Host

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
                'number' = $Version
            }
        } | ConvertTo-JSON

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content/$PageId" `
            -Method 'Put' `
            -Headers @{
                'Authorization' = "Bearer $([System.Net.NetworkCredential]::new('', $script:PATS[$Host_]).Password)"
            } `
            -ContentType "application/json" `
            -Body $transportBody `
            -OutVariable rawResponse | Out-Null
    }

    End
    {
        $response = ($rawResponse.Content | ConvertFrom-JSON)
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
        [Parameter(Mandatory)] [PSObject] $Manifest
    )

    Begin
    {
        $pageMeta = Get-PageMeta `
                        -Host $hostname `
                        -Space $spaceName `
                        -Title $Title `
                        -Manifest $Manifest
    }

    Process
    {
        if ($pageMeta.ContentHash -eq $_)
        {
            Write-Host "skipping (no changes): $Title"

            return
        }

        $pageId = $pageMeta.PageId

        $path = Join-Path $basepath 'content' "$_"

        $pageContent = Get-Content $path | Out-String

        $prettyName = $Title

        if ($data.pages[$_].ancestor_id)
        {
            $ancestorTitle = $data.pages[$data.pages[$_].ancestor_id].title

            $ancestorPageMeta = Get-PageMeta `
                                    -Host $hostname `
                                    -Space $spaceName `
                                    -Title $ancestorTitle `
                                    -CacheIndexFile $cacheIndexFile

            if ($ancestorPageMeta)
            {
                $ancestorPageId = $ancestorPageMeta.PageId
            }

            $prettyName += " [$ancestorPageId]"
        }

        if (-Not $pageId)
        {
            Write-Host ("create ${_}: $prettyName")

            try {
                $pageMeta = New-Page `
                                -Host $hostname `
                                -Space $spaceName `
                                -Title $pageTitle `
                                -Content $pageContent `
                                -Ancestor $ancestorPageId
            }

            catch
            {
                Write-Host "error (skipping): $prettyName"

                return
            }


            Register-PageMeta `
                -PageId $pageMeta.PageId `
                -Version $pageMeta.Version `
                -Title $pageTitle `
                -ContentHash $_ `
                -CacheIndexFile $cacheIndexFile
        }
        else
        {
            Write-Host ("update ${_} (${pageId}): $prettyName")

            $version = $pageMeta.Version + 1

            try
            {
                Update-Page `
                    -Host $hostname `
                    -PageId $pageId `
                    -Space $spaceName `
                    -Title $pageTitle `
                    -Version  $version `
                    -Content $pageContent `
                    -Ancestor $ancestorPageId
            }

            catch
            {
                Write-Host "error (skipping): $prettyName"

                return
            }

            Register-PageMeta `
                -PageId $pageMeta.PageId `
                -Version $version `
                -Title $pageTitle `
                -ContentHash $_ `
                -CacheIndexFile $cacheIndexFile
        }
    }
}