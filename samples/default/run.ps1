#!/usr/bin/env pwsh
<#
    .SYNOPSIS
        default reference implementation

    .DESCRIPTION
        This script is a reference implementation for the basic usage of this
        PowerShell module. It uses demo data which can be used to do a basic
        integration test.
#>
Param(
    # Confluence instance hostname
    [Parameter(Mandatory)] [String]$Hostname,
    # Confluence space id
    [Parameter(Mandatory)] [String]$Space,
    # Confluence personal access token
    [Parameter(Mandatory)] [String]$PersonalAccessToken,
    # Manifest file location
    [Parameter()] [String]$ManifestFile = "$PSScriptRoot/data/manifest.json",
    # flag for forcing update of pages and attachments, should they already
    # exist
    [Parameter()] [Switch]$Force,
    # flag for exiting immediately upon any failure, the default behavior is to
    # just skip the failure and continue
    [Parameter()] [Switch]$Strict
)

$ErrorActionPreference = "Stop"
$DebugPreference = 'Continue'

Import-Module "$PSScriptRoot/../../src/victorykit.PSConfluencePublisher.psd1"

Write-Host "initializing manifest..."

# create a high-level manifest pseudo-object. As mentioned, this is just a
# pseduo-object to organize things a little better. 
$manifest = Initialize-Manifest -Path $ManifestFile

Write-Host "initializing and testing connectivity..."

# create a high-level connection pseudo-object. As mentioned, this is just a
# pseduo-object to organize things a little better.
$connection = Initialize-Connection `
                  -Host $Hostname `
                  -Space $Space `
                  -PersonalAccessToken $PersonalAccessToken

Write-Host "fetching pages metadata..."

# unidirectionally synchronize all remote metadata to local (in-memory)
# manifest. If locally cached metadata is sufficient, it will skip getting the
# data from the remote, unless the -Force switch is specified.
$manifest.Manifest.Pages = Get-PageMeta `
                               -Host $Hostname `
                               -Manifest $manifest.Manifest.Pages `
                               -Space $Space `
                               -Force:$Force `
                               -Strict:$Strict

Write-Host "publishing pages ($($manifest.Manifest.Pages.Count))..."

# publish all pages listed in manifest
Publish-Pages `
    -Manifest $manifest `
    -Connection $connection `
    -Force:$Force `
    -Strict:$Strict

Write-Host "fetching attachments metadata..."

# unidirectionally synchronize all remote attachment metadata to local 
# (in-memory) manifest. If locally cached metadata is sufficient, it will skip 
# getting the data from the remote, unless the -Force switch is specified.
$manifest.Manifest.Attachments = Get-AttachmentMeta `
                                     -Host $Hostname `
                                     -Manifest $manifest.Manifest.Attachments `
                                     -Index $manifest.Index.Attachments `
                                     -PagesManifest $manifest.Manifest.Pages `
                                     -PagesIndex $manifest.Index.Pages `
                                     -Space $Space `
                                     -Force:$Force `
                                     -Strict:$Strict

Write-Host "publishing attachments ($($manifest.Manifest.Attachments.Count))..."

# publish all pages listed in manifest
Publish-Attachments `
    -Manifest $manifest `
    -Connection $connection `
    -Force:$Force `
    -Strict:$Strict

Write-Host "dumping manifest to filesystem..."

# write back to disk
Set-Manifest `
    -Manifest $manifest.Manifest `
    -File $manifest.Path `
    -Backup $true | Out-Null

