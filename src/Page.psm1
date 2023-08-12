#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


function New-Page
{
    <#
        .SYNOPSIS
            Add a confluence page

        .DESCRIPTION

            This function is unaware of the publishing status of ancestors and
            assumes that ancestral hierarchy is maintained through the
            manifest's item order.

            If a page's metadata does not include a reference, it will be
            treated as a publishing failure and therefore not output the
            original metadata.

        .OUTPUTS

            When no $Title is provided and the $Manifest array only contains 1
            page metadata, the ``Count`` attribute is faulty. Why? Don't know.

        .EXAMPLE
            Add-ConfluencePage `
                -Host 'confluence.contoso.com' `
                -Space 'TIARA' `
                -Title 'Testitest' `
                -Content @{}
    #>
    Param(
        # confluence instance hostname
        [Parameter(Mandatory)] [string]$Host,
        # name of the Confluence space to publish to
        [Parameter(Mandatory)] [string]$Space,
        # title of page to be published
        [Parameter()] [string]$Title,
        # pages manifest
        [Parameter(Mandatory, ValueFromPipeline)] 
            [Collections.Hashtable[]]$Manifest,
        # pages manifest index, mandatory for ancestor lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # flag on whether to fail hard, or just continue
        [Parameter()] [Switch]$Strict
    )

    Begin
    {
        $pat = Get-PersonalAccessToken $Host
    }

    Process
    {
        If ($Title -And $Manifest[$Index.$Title])
        {
            $Manifest = @(
                $Manifest[$Index.$Title]
            )
        }

        ForEach($pageMeta in $Manifest)
        {
            If ($Title -And $pageMeta.Title -ne $Title) {continue}

            ElseIf (-Not $pageMeta.Ref)
            {
                $errMsg = "no reference to local content for page ``$Title``."

                If ($Strict) {throw $errMsg}

                Write-Host $errMsg

                continue
            }

            ElseIf ($pageMeta.Id)
            {

                Write-Debug "skipping, page already published: $($pageMeta.Id)"

                $pageMeta

                continue
            }

            Else
            {
                $content = Get-Content -Path $pageMeta.Ref

                $contentHash = (Get-StringHash $content).Hash

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

                Try
                {
                    Invoke-WebRequest `
                        -Uri "https://${Host}/rest/api/content" `
                        -Method 'Post' `
                        -Headers @{
                            'Authorization' = "Bearer $pat"
                        } `
                        -ContentType "application/json" `
                        -Body $transportBody `
                        -OutVariable rawResponse | Out-Null
                }

                Catch
                {
                    $errMsg = "skipping ``$pageMeta.Title``: $_"

                    If ($Strict)
                    {
                        throw $errMsg
                    }

                    Write-Host $errMsg

                    continue
                }

                $response = ($rawResponse.Content | ConvertFrom-JSON)

                $pageMeta | Add-Member `
                                -NotePropertyName 'Id' `
                                -NotePropertyValue $response.id `
                                -Force

                $pageMeta | Add-Member `
                                -NotePropertyName 'Version' `
                                -NotePropertyValue $response.version.number `
                                -Force

                $pageMeta | Add-Member `
                                -NotePropertyName 'Hash' `
                                -NotePropertyValue $contentHash `
                                -Force

                If (
                    ($Title -And $pageMeta.Title -eq $Title) -Or 
                    $Manifest.Count -eq 1
                )
                {
                    # TODO: further research mechanism of expanding single item
                    # array pipelines. For now we have to apply the unary
                    # operator, otherwise we get a wrong count on the output
                    ,@($pageMeta)

                    break
                }

                Else
                {
                    $pageMeta
                }
            }
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
        # pages manifest
        [Parameter(Mandatory)] [Array] $Manifest,
        # pages manifest index
        [Parameter()] [Collections.Hashtable] $Index
    )

    Process
    {
        $pageMeta = Get-PageMeta `
            -Host $Host `
            -Space $Space `
            -Title $Title `
            -Manifest $Manifest `
            -Index $Index

        if (-Not $pageMeta.Ref)
        {
            throw "no reference to local content for page '$Title'."
        }

        if (-Not $pageMeta.Id)
        {
            throw "no id for page '$Title'."
        }

        $content = Get-Content -Path $pageMeta.Ref

        $hash = (Get-StringHash $content).Hash

        if ($hash -eq $pageMeta.Hash)
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
        $version = $pageMeta.Version + 1

        $transportBody = @{
            'id' = $PageMeta.Id
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
            'version' = @{
                'number' = $version
            }
        } | ConvertTo-JSON

        Invoke-WebRequest `
            -Uri "https://${Host}/rest/api/content/$($PageMeta.Id)" `
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

        Update-PageMeta `
            -Title $Title `
            -Id $pageMeta.Id `
            -Version $response.version.number `
            -Hash $hash `
            -Manifest $Manifest `
            -Index $Index
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
