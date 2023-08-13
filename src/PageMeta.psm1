
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
        [Parameter(Mandatory)] [string] $Host,
        # Page title
        [Parameter()] [string] $Title,
        # Confluence space id
        [Parameter(Mandatory)] [string] $Space,
        # pages manifest
        [Parameter(Mandatory, ValueFromPipeline)] [Array] $Manifest,
        # page metadata index for faster lookup of single page
        [Parameter()] [Collections.Hashtable] $Index,
        # force to get metadata from remote
        [Parameter()] [Switch] $Force = $false,
        # throw an exception on error
        [Parameter()] [Switch] $Strict = $true
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
                Write-Debug "local (cache): $($pageMeta.Title) ($($pageMeta.Id))"

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
                    Write-Debug "local: $($pageMeta.Title) (no remote)"
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
