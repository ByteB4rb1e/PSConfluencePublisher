#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


function New-Attachment
{
    <#
        .SYNOPSIS

            Add a new attachment

        .DESCRIPTION


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
        [Parameter()] [string]$Name,
        # attachments manifest
        [Parameter(Mandatory, ValueFromPipeline)] 
            [PSCustomObject[]]$Manifest,
        # attachments manifest index, mandatory for ancestor lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # pages manifest
        [Parameter(Mandatory)] 
            [PSCustomObject[]]$PagesManifest,
        # pages manifest index, mandatory for container page lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$PagesIndex,
        # flag on whether to fail hard, or just continue
        [Parameter()] [Switch]$Strict
    )

    Begin
    {
        $pat = Get-PersonalAccessToken $Host
    }

    Process
    {
        If ($Name -And $Manifest[$Index.$Name])
        {
            $Manifest = @(
                $Manifest[$Index.$Name]
            )
        }

        ForEach($attachmentMeta in $Manifest)
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
            ElseIf (-Not $attachmentMeta.Ref)
            {
                $errMsg = (
                    "``$($attachmentMeta.Name)``: no reference to local " + 
                    'content for attachment .'
                )

                If ($Strict) {throw $errMsg}

                Write-Host $errMsg

                # not outputting the metadata, since it's invalid anyway

                continue
            }

            ElseIf ($attachmentMeta.Id)
            {

                Write-Debug (
                    "New-Attachment: ``$($attachmentMeta.Name)``: skipping, " +
                    "already published ($($attachmentMeta.Id))"
                )

                $attachmentMeta

                continue
            }

            Else
            {
                Write-Host (
                    "New-Attachment: ``$($attachmentMeta.Name)``: creating"
                )

                Try
                {
                    $rawContent = [IO.File]::ReadAllBytes($attachmentMeta.Ref)

                    $content = [Text.Encoding]::GetEncoding(
                        'ISO-8859-1'
                    ).GetString($rawContent)
                }

                Catch
                {
                    $errMsg = "``New-Attachment: $($attachmentMeta.Name)``: $_"

                    If ($Strict) {throw $errMsg}

                    Write-Host $errMsg

                    continue
                }

                $boundary = [Guid]::NewGuid().ToString()

                $LF = "`r`n";

                $transportBody = ( 
                    "--$boundary",
                    (
                        "Content-Disposition: form-data; name=`"file`"; " +
                        "filename=`"$($attachmentMeta.Name)`""
                    ),
                    "Content-Type: $($attachmentMeta.MimeType)$LF",
                    $content,
                    "--$boundary--$LF" 
                ) -join $LF

                $uri = (
                    "https://${Host}/rest/api/content/" +
                    "$($containerPageMeta.Id)/child/attachment"
                )

                Try
                {
                    Invoke-WebRequest `
                        -Uri $uri `
                        -Method 'Post' `
                        -Headers @{
                            'Authorization' = "Bearer $pat"
                            'X-Atlassian-Token' = 'nocheck'
                        } `
                        -ContentType (
                            "multipart/form-data; boundary=`"$boundary`""
                        ) `
                        -Body $transportBody `
                        -OutVariable rawResponse | Out-Null
                }

                Catch
                {
                    $errMsg = "skipping ``$($attachmentMeta.Name)``: $($_)"

                    If ($Strict)
                    {
                        $_

                        throw $errMsg
                    }

                    Write-Host $errMsg

                    continue
                }

                $response = ($rawResponse.Content | ConvertFrom-JSON)

                $result = $response.results[0]

                $attachmentMeta | Add-Member `
                                      -NotePropertyName 'Id' `
                                      -NotePropertyValue $result.id `
                                      -Force

                $attachmentMeta | Add-Member `
                                      -NotePropertyName 'Version' `
                                      -NotePropertyValue (
                                          $result.version.number
                                      ) `
                                      -Force

                $contentHash = (Get-StringHash $content).Hash

                $attachmentMeta | Add-Member `
                                      -NotePropertyName 'Hash' `
                                      -NotePropertyValue $contentHash `
                                      -Force

                If (
                    ($Title -And $attachmentMeta.Title -eq $Name) -Or 
                    $Manifest.Count -eq 1
                )
                {
                    # TODO: further research mechanism of expanding single item
                    # array pipelines. For now we have to apply the unary
                    # operator, otherwise we get a wrong count on the output
                    ,@($attachmentMeta)

                    break
                }

                Else
                {
                    $attachmentMeta
                }
            }
        }
    }
}


function Update-Attachment
{
    <#
        .SYNOPSIS

            Add a new attachment

        .DESCRIPTION


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
        [Parameter()] [string]$Name,
        # attachments manifest
        [Parameter(Mandatory, ValueFromPipeline)] 
            [PSCustomObject[]]$Manifest,
        # attachments manifest index, mandatory for ancestor lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # pages manifest
        [Parameter(Mandatory)] 
            [PSCustomObject[]]$PagesManifest,
        # pages manifest index, mandatory for container page lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$PagesIndex,
        # flag on whether to fail hard, or just continue
        [Parameter()] [Switch]$Strict,
        # flag on whether to force update of attachment, regardless of content
        # changes
        [Parameter()] [Switch]$Force
    )

    Begin
    {
        $pat = Get-PersonalAccessToken $Host
    }

    Process
    {
        If ($Name -And $Manifest[$Index.$Name])
        {
            $Manifest = @(
                $Manifest[$Index.$Name]
            )
        }

        ForEach($attachmentMeta in $Manifest)
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

            ElseIf (-Not $containerPageMeta.Id)
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

            ElseIf (-Not $attachmentMeta.Ref)
            {
                $errMsg = (
                    "``$($attachmentMeta.Name)``: no reference to local " + 
                    'content for attachment .'
                )

                If ($Strict) {throw $errMsg}

                Write-Host $errMsg

                # not outputting the metadata, since it's invalid anyway

                continue
            }

            ElseIf (-Not $attachmentMeta.Id)
            {
                $errMsg = (
                    "Update-Attachment: ``$($attachmentMeta.Name)``: unknown " +
                    "attachment id."
                )

                If ($Strict) {throw $errMsg}

                Write-Host "$errMsg Skipping."

                $attachmentMeta

                continue
            }

            ElseIf (-Not $attachmentMeta.Version)
            {
                Write-Host = (
                    "New-Attachment: ``$($attachmentMeta.Name)``: skipping, " +
                    "unknown (current) version"
                )
            }

            Else
            {

                Try
                {
                    $rawContent = [IO.File]::ReadAllBytes($attachmentMeta.Ref)

                    $content = [Text.Encoding]::GetEncoding(
                        'ISO-8859-1'
                    ).GetString($rawContent)
                }

                Catch
                {
                    $errMsg = "``New-Attachment: $($attachmentMeta.Name)``: $_"

                    If ($Strict) {throw $errMsg}

                    Write-Host $errMsg

                    continue
                }

                $version = [Int]$attachmentMeta.Version + 1

                $contentHash = (Get-StringHash $content).Hash

                If (
                    $attachmentMeta.Hash -And 
                    $attachmentMeta.Hash -eq $contentHash -And
                    -Not $Force
                )
                {
                    Write-Debug (
                        "Update-Attachment: ``$($attachmentMeta.Name)``: " +
                        "skipping, no content changes"
                    )

                    $attachmentMeta

                    continue
                }

                Else
                {
                    Write-Host (
                        "Update-Attachment: ``$($attachmentMeta.Name)``: " +
                        "updating"
                    )
                }

                $boundary = [Guid]::NewGuid().ToString()

                $LF = "`r`n";

                $transportBody = ( 
                    "--$boundary",
                    (
                        "Content-Disposition: form-data; name=`"file`"; " +
                        "filename=`"$($attachmentMeta.Name)`""
                    ),
                    "Content-Type: $($attachmentMeta.MimeType)$LF",
                    $content,
                    "--$boundary--$LF" 
                ) -join $LF

                $uri = (
                    "https://${Host}/rest/api/content/" +
                    "$($containerPageMeta.Id)/child/attachment/" +
                    "$($attachmentMeta.Id)/data"
                )

                Try
                {
                    Invoke-WebRequest `
                        -Uri $uri `
                        -Method 'Post' `
                        -Headers @{
                            'Authorization' = "Bearer $pat"
                            'X-Atlassian-Token' = 'nocheck'
                        } `
                        -ContentType (
                            "multipart/form-data; boundary=`"$boundary`""
                        ) `
                        -Body $transportBody | Out-Null
                }

                Catch
                {
                    $errMsg = "skipping ``$($attachmentMeta.Name)``: $($_)"

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

                $attachmentMeta | Add-Member `
                                      -NotePropertyName 'Version' `
                                      -NotePropertyValue $version `
                                      -Force

                $attachmentMeta | Add-Member `
                                      -NotePropertyName 'Hash' `
                                      -NotePropertyValue $contentHash `
                                      -Force

                If (
                    ($Title -And $attachmentMeta.Title -eq $Name) -Or 
                    $Manifest.Count -eq 1
                )
                {
                    # TODO: further research mechanism of expanding single item
                    # array pipelines. For now we have to apply the unary
                    # operator, otherwise we get a wrong count on the output
                    ,@($attachmentMeta)

                    break
                }

                Else
                {
                    $attachmentMeta
                }
            }
        }
    }
}

function Publish-Attachment
{
    Param(
        # confluence instance hostname
        [Parameter(Mandatory)] [string]$Host,
        # name of the Confluence space to publish to
        [Parameter(Mandatory)] [string]$Space,
        # title of page to be published
        [Parameter()] [string]$Name,
        # attachments manifest
        [Parameter(Mandatory,ValueFromPipeline)] 
            [PSCustomObject[]]$Manifest,
        # attachments manifest index, mandatory for ancestor lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$Index,
        # pages manifest
        [Parameter(Mandatory)] 
            [PSCustomObject[]]$PagesManifest,
        # pages manifest index, mandatory for container page lookup
        [Parameter(Mandatory)] [Collections.Hashtable]$PagesIndex,
        # flag on whether to fail hard, or just continue
        [Parameter()] [Switch]$Strict,
         # flag on whether to force update of page, regardless of content
        [Parameter()] [Switch]$Force
   )

    Process
    {
        $result = Update-Attachment `
                      -Host $Host `
                      -Space $Space `
                      -Manifest $Manifest `
                      -Index $Index `
                      -PagesManifest $PagesManifest `
                      -PagesIndex $PagesIndex `
                      -Strict:$Strict `
                      -Force:$Force

        $result = New-Attachment `
                      -Host $Host `
                      -Space $Space `
                      -Manifest $manifest `
                      -Index $Index `
                      -PagesManifest $PagesManifest `
                      -PagesIndex $PagesIndex `
                      -Strict:$Strict
    }

    End
    {
        $result
    }
}

