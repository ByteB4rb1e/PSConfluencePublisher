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
        [Parameter(Mandatory,ValueFromPipeline)] 
            [PSCustomObject[]]$Manifest,
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
                $errMsg = ("``$($pageMeta.Title)``: no reference to local " + 
                           'content for page .')

                If ($Strict) {throw $errMsg}

                Write-Host $errMsg

                continue
            }

            ElseIf ($pageMeta.Id)
            {
                Write-Debug (
                    "New-Page: ``$($pageMeta.Title)``: skipping, already " +
                    "published ($($pageMeta.Id))"
                )

                $pageMeta

                continue
            }

            Else
            {
                Write-Host "New-Page: ``$($pageMeta.Title)``: creating"

                Try
                {
                    $content = Get-Content -Path $pageMeta.Ref | Out-String
                }

                Catch
                {
                    $errMsg = "``New-Page: $($PageMeta.Title)``: $_"

                    If ($Strict) {throw $errMsg}

                    Write-Host $errMsg

                    continue
                }

                $contentHash = (Get-StringHash $content).Hash

                $transportBody = @{
                    'type' = 'page'
                    'title' = $pageMeta.Title
                    'space' = @{
                        'key' = $Space
                    }
                    'body' = @{
                        'storage' = @{
                            'value' = $content
                            'representation' = 'storage'
                        }
                    }
                }

                If ($pageMeta.AncestorTitle)
                {
                    $ancestorPageMeta =  $Manifest[
                        $Index."$($pageMeta.AncestorTitle)"
                    ]

                    If (-Not $ancestorPageMeta)
                    {
                        Throw (
                            "ancestor (``$($ancestorPageMeta.Title)``) of " +
                            "``$($pageMeta.Title)`` does not have an id. " +
                            "This indicates, that the ancestor has not been " +
                            "published and therefore the pages manifest may " +
                            "not be in the correct order."
                        )
                    }

                    $transportBody.ancestors = @(
                        @{'id' = $ancestorPageMeta.Id}
                    )
                }

                $rawTransportBody = (
                    $transportBody | ConvertTo-JSON `
                                         -WarningAction 'SilentlyContinue'
                )

                Try
                {
                    Invoke-WebRequest `
                        -Uri "https://${Host}/rest/api/content" `
                        -Method 'Post' `
                        -Headers @{
                            'Authorization' = "Bearer $pat"
                        } `
                        -ContentType "application/json" `
                        -Body $rawTransportBody `
                        -OutVariable rawResponse | Out-Null
                }

                Catch
                {
                    $errMsg = "skipping ``$($pageMeta.Title)``: $($_)"

                    If ($Strict)
                    {
                        $_

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
                                -NotePropertyValue "1" `
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
            Update an existing Confluence page

        .DESCRIPTION

            This function is unaware of the publishing status of ancestors and
            assumes that ancestral hierarchy is maintained through the
            manifest's item order, therefore an index must be supplied.

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
            [PSCustomObject[]]$Manifest,
        # pages manifest index, mandatory for ancestor lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # flag on whether to fail hard, or just continue
        [Parameter()] [Switch]$Strict,
        # flag on whether to force update of page, regardless of content
        [Parameter()] [Switch]$Force
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

            ElseIf (-Not $pageMeta.Id)
            {
                $errMsg = (
                    "Update-Page: ``$($pageMeta.Title)``: unknown page id."
                )

                If ($Strict) {throw $errMsg}

                Write-Host "$errMsg Skipping."

                $pageMeta

                continue
            }

            ElseIf (-Not $pageMeta.Version)
            {
                Write-Host (
                    "Update-Page: ``$($pageMeta.Title)``: unknown (current) " +
                    "version. Skipping."
                )

                $pageMeta

                continue
            }

            Else
            {
                Try
                {
                    $content = Get-Content -Path $pageMeta.Ref | Out-String
                }

                Catch
                {
                    $errMsg = "``$Title``: $_"

                    If ($Strict) {throw $errMsg}

                    Write-Host $errMsg

                    continue
                }

                $version = [Int]$pageMeta.Version + 1

                $contentHash = (Get-StringHash $content).Hash

                If (
                    $pageMeta.Hash -And 
                    $pageMeta.Hash -eq $contentHash -And
                    -Not $Force
                )
                {
                    Write-Debug (
                        "Update-Page: ``$($pageMeta.Title)``: skipping, no " +
                        "content changes"
                    )

                    $pageMeta

                    continue
                }

                Else
                {
                    Write-Host (
                        "Update-Page: ``$($pageMeta.Title)``: updating"
                    )
                }

                # status needs to be set as to restore the page, if it is
                # trashed
                $transportBody = @{
                    'id' = $PageMeta.Id
                    'type' = 'page'
                    'title' = $pageMeta.Title
                    'space' = @{
                        'key' = $Space
                    }
                    'body' = @{
                        'storage' = @{
                            'value' = $content
                            'representation' = 'storage'
                        }
                    }
                    'status' = 'current'
                    'version' = @{
                        'number' = $version
                    }
                } 

                If ($pageMeta.AncestorTitle)
                {
                    $ancestorPageMeta = $Manifest[
                        $Index."$($pageMeta.AncestorTitle)"
                    ]

                    If (-Not $ancestorPageMeta)
                    {
                        Throw (
                            "ancestor (``$($ancestorPageMeta.Title)``) of " +
                            "``$($pageMeta.Title)`` does not have an id. " +
                            "This indicates, that the ancestor has not been " +
                            "published and therefore the pages manifest may " +
                            "not be in the correct order."
                        )
                    }

                    $transportBody.ancestors = @(
                        @{'id' = $ancestorPageMeta.Id}
                    )
                }

                $rawTransportBody = (
                    $transportBody | ConvertTo-JSON `
                                         -WarningAction 'SilentlyContinue'
                )

                Try
                {
                    Invoke-WebRequest `
                        -Uri ("https://${Host}/rest/api/content/" +
                              $PageMeta.Id) `
                        -Method 'Put' `
                        -Headers @{
                            'Authorization' = "Bearer $pat"
                        } `
                        -ContentType "application/json" `
                        -Body $rawTransportBody `
                        -OutVariable rawResponse | Out-Null
                }

                Catch
                {
                    $errMsg = "skipping ``$($pageMeta.Title)``: $_"

                    If ($Strict)
                    {
                        $_

                        throw $errMsg
                    }

                    Write-Host $errMsg

                    continue
                }

                # response isn't needed since no field will be updated by the
                # Confluence instance itself
                #$response = ($rawResponse.Content | ConvertFrom-JSON)

                $pageMeta | Add-Member `
                                -NotePropertyName 'Version' `
                                -NotePropertyValue $version `
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


function Publish-Page
{
    Param(
        # confluence instance hostname
        [Parameter(Mandatory)] [string]$Host,
        # name of the Confluence space to publish to
        [Parameter(Mandatory)] [string]$Space,
        # title of page to be published
        [Parameter()] [string]$Title,
        # pages manifest
        [Parameter(Mandatory)] 
            [PSCustomObject[]]$Manifest,
        # pages manifest index, mandatory for ancestor lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # flag on whether to fail hard, or just continue
        [Parameter()] [Switch]$Strict,
        # flag on whether to force update of page, regardless of content
        [Parameter()] [Switch]$Force
    )

    Process
    {
        $result = Update-Page `
                      -Host $Host `
                      -Space $Space `
                      -Manifest $Manifest `
                      -Index $Index `
                      -Strict:$Strict `
                      -Force:$Force

        $result = New-Page `
                      -Host $Host `
                      -Space $Space `
                      -Manifest $result `
                      -Index $Index `
                      -Strict:$Strict
    }

    End
    {
        $result
    }
}
