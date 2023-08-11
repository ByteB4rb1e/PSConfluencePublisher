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
    [Parameter(Mandatory)] [String] $Hostname,
    [Parameter(Mandatory)] [String] $Space,
    [Parameter(Mandatory)] [String] $PersonalAccessToken,
    [Parameter()] [String] $ManifestFile = 'data/manifest.json'
)

Import-Module "$PSScriptRoot/../../src/PSConfluencePublisher.psd1"

# create a high-level manifest pseudo-object
$manifest = Initialize-Manifest -Path $ManifestFile

# create a high-level connection pseudo-object 
$connection = Initialize-Connection `
                  -Host $Hostname `
                  -Space $Space `
                  -PersonalAccessToken $PersonalAccessToken

# unidirectionally synchronize all remote metadata to local (in-memory) manifest
$manifest.Manifest.Pages = Get-PageMeta `
                               -Host $Hostname `
                               -Manifest $manifest.Manifest.Pages `
                               -Space $Space `
                               -Force

# write back to disk
Set-Manifest `
    -Manifest $manifest.Manifest `
    -File $manifest.Path `
    -Backup $true
