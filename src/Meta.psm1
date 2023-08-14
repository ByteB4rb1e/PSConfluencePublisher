$ErrorActionPreference = "Stop"


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
        # Confluence instance hostname
        [Parameter(Mandatory)] [string]$Host,
        # Page title
        [Parameter()] [string]$Title,
        # Confluence space id
        [Parameter(Mandatory)] [string]$Space,
        # pages manifest
        [Parameter(Mandatory, ValueFromPipeline)] [Array]$Manifest,
        # page metadata index for faster lookup of single page
        [Parameter()] [Collections.Hashtable]$Index,
        # force to get metadata from remote
        [Parameter()] [Switch]$Force,
        # throw an exception on error
        [Parameter()] [Switch]$Strict
    )

    Process
    {
        If ($Title -And $Index -And $Manifest[$Index.$Title].Id)
        {
            $Manifest[$Index.$Title]

            return
        }

        ForEach ($pageMeta in $Manifest)
        {
            If ($Title -And $pageMeta.Title -ne $Title) {continue}

            If ($pageMeta.Id -And -Not $Force)
            {
                Write-Debug (
                    "Get-PageMeta: ``$($pageMeta.Title)``: " + 
                    "using locally cached metadata ($($pageMeta.Id))"
                )

                $pageMeta
            }

            Else
            {
                $escapedTitle = [Uri]::EscapeDataString($pageMeta.Title)

                $query = (
                    "title=${escapedTitle}&spaceKey=${Space}&expand=version"
                )

                Invoke-WebRequest `
                    -Uri "https://${Host}/rest/api/content?$query" `
                    -Method 'Get' `
                    -Headers @{
                        'Authorization' = 'Bearer ' +
                                          $(Get-PersonalAccessToken $Host)
                    } `
                    -OutVariable response | Out-Null

                $results = ($response.Content | ConvertFrom-JSON).results

                If ($results.Count -gt 1)
                {
                    $errMsg = "error: more than one result for query: $query"

                    If ($Strict) {throw $errMsg}

                    Write-Host $errMsg

                    $pageMeta

                    continue
                }

                ElseIf ($results.Count -eq 1) 
                {
                    Write-Debug (
                        "Get-PageMetadata: ``$($pageMeta.Title)``: " +
                        "updating metadata through remote ($($results[0].id))"
                    )

                    $pageMeta | Add-Member `
                                    -NotePropertyName Id `
                                    -NotePropertyValue $results[0].id `
                                    -Force

                    $pageMeta | Add-Member `
                                    -NotePropertyName 'Version' `
                                    -NotePropertyValue `
                                        $results[0].version.number `
                                    -Force
                }

                Else
                {
                    Write-Debug (
                        "Get-PageMetadata: ``$($pageMeta.Title)``: " +
                        "no remote, using (partial) local"
                    )

                    If ($pageMeta.Version)
                    {
                        $pageMeta.PSObject.Properties.Remove('Version')
                    }

                    If ($pageMeta.Id)
                    {
                        $pageMeta.PSObject.Properties.Remove('Id')
                    }
                }

                If (-Not $pageMeta.Hash)
                {
                    $content = Get-Content $pageMeta.Ref | Out-String

                    $hash = (Get-StringHash $content).Hash

                    $pageMeta | Add-Member `
                                    -NotePropertyName 'Hash' `
                                    -NotePropertyValue $hash `
                                    -Force
                }

                $pageMeta
            }
        }
    }
}


function Get-AttachmentMeta
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
        # Confluence instance hostname
        [Parameter(Mandatory)] [string]$Host,
        # Confluence space id
        [Parameter(Mandatory)] [string]$Space,
        # Attachment name
        [Parameter()] [string]$Name,
        # attachments manifest
        [Parameter(Mandatory, ValueFromPipeline)] [Array]$Manifest,
        # page metadata index for faster lookup of single page
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # pages manifest
        [Parameter(Mandatory)] [Array]$PagesManifest,
        # page metadata index for faster lookup of single page
        [Parameter()] [Collections.Hashtable]$PagesIndex,
        # force to get metadata from remote
        [Parameter()] [Switch]$Force,
        # throw an exception on error
        [Parameter()] [Switch]$Strict
    )

    Begin
    {
        $pat = Get-PersonalAccessToken $Host
    }

    Process
    {
        If ($Name -And $Index -And $Manifest[$Index.$Name].Id)
        {
            $Manifest[$Index.$Name]

            return
        }

        ForEach ($attachmentMeta in $Manifest)
        {
            If ($Name -And $attachmentMeta.Name -ne $Name) {continue}

            $containerPageMeta = $PagesManifest[
                $PagesIndex."$($attachmentMeta.ContainerPageTitle)"
            ]

            If (-Not $containerPageMeta)
            {
                throw (
                    "Get-AttachmentMeta: ``$($attachmentMeta.Name)``: " + 
                    "unable to lookup metadata for container page " +
                    "title ``$($attachmentMeta.ContainerPageTitle)``." +
                    "This is fatal."
                )
            }

            If (-Not $containerPageMeta.Id)
            {
                $errMsg = (
                    "Get-AttachmentMeta: ``$($attachmentMeta.Name)``: " + 
                    "container page titled" +
                    "``$($attachmentMeta.ContainerPageTitle)`` " + 
                    "has no id, which means that the page has " +
                    "(presumably) not yet been published."
                )

                If ($Strict) {throw $errMsg}

                Write-Host "$errMsg Continuing nonetheless..."

                $attachmentMeta

                continue
            }

            If ($attachmentMeta.Id -And -Not $Force)
            {
                Write-Debug (
                    "Get-AttachmentMeta: ``$($attachmentMeta.Name)``: " + 
                    "using locally cached metadata ($($attachmentMeta.Id))"
                )

                $attachmentMeta
            }

            Else
            {
                $escapedName = [Uri]::EscapeDataString($attachmentMeta.Name)

                $query = "filename=${escapedName}&expand=version"

                $uri = (
                    "https://${Host}/rest/api/content/" +
                    "$($containerPageMeta.Id)/child/attachment?$query"
                )

                Invoke-WebRequest `
                    -Uri $uri `
                    -Method 'Get' `
                    -Headers @{
                        'Authorization' = "Bearer $pat"
                    } `
                    -OutVariable response | Out-Null

                $results = ($response.Content | ConvertFrom-JSON).results

                If ($results.Count -gt 1)
                {
                    $errMsg = (
                        "Get-AttachmentMeta: ``$($attachmentMeta.Name)``: " + 
                        "error: more than one result for query: $query"
                    )

                    If ($Strict) {throw $errMsg}

                    Write-Host $errMsg

                    $attachmentMeta

                    continue
                }

                ElseIf ($results.Count -eq 1) 
                {
                    Write-Debug (
                        "Get-AttachmentMeta: ``$($attachmentMeta.Name)``: " + 
                        "updating metadata through remote ($($results[0].id))"
                    )

                    $attachmentMeta | Add-Member `
                                          -NotePropertyName Id `
                                          -NotePropertyValue $results[0].id `
                                          -Force

                    $attachmentMeta | Add-Member `
                                          -NotePropertyName 'Version' `
                                          -NotePropertyValue `
                                              $results[0].version.number `
                                          -Force
                }

                Else
                {
                    Write-Debug (
                        "Get-AttachmentMetadata: ``$($attachmentMeta.Name)``" +
                        ": no remote, using (partial) local"
                    )

                    If ($attachmentMeta.Version)
                    {
                        $attachmentMeta.PSObject.Properties.Remove('Version')
                    }

                    If ($attachmentMeta.Id)
                    {
                        $attachmentMeta.PSObject.Properties.Remove('Id')
                    }
                }

                If (-Not $attachmentMeta.Hash)
                {
                    $content = Get-Content $attachmentMeta.Ref | Out-String

                    $hash = (Get-StringHash $content).Hash

                    $attachmentMeta | Add-Member `
                                          -NotePropertyName 'Hash' `
                                          -NotePropertyValue $hash `
                                          -Force
                }

                $attachmentMeta
            }
        }
    }
}
