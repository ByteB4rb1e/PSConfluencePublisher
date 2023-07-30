#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


$script:schema = Get-Content (
    Join-Path $PSScriptRoot 'manifest.schema.json'
) | Out-String


function Get-Manifest
{
    <#
        .SYNOPSIS
            Load the archive manifest

        .EXAMPLE
            Get-Manifest 'manifest.json'
    #>
    Param(
        # filesystem location of manifest
        [Parameter(Mandatory)] [string] $File
    )

    Process
    {
        try
        {
            $raw = Get-Content $File
        }

        catch
        { 
            $raw = '{"pages":{}, "attachments": {}}'
        }

        $raw | Test-JSON -Schema $script:schema | Out-Null

        $data = $raw | ConvertFrom-JSON
    }
}


function Set-Manifest
{
    <#
        .SYNOPSIS
            Dump the archive manifest

        .EXAMPLE
            Set-Manifest 'manifest.json'
    #>
    Param(
        # manifest object
        [Parameter(Mandatory)] [PSObject] $Manifest,
        # filesystem location of manifest
        [Parameter(Mandatory)] [string] $File,
        # create a backup first
        [Parameter()] [bool] $Backup = $false
    )

    Process
    {
        $raw = $Manifest | ConvertTo-JSON

        $raw | Test-JSON -Schema $script:schema

        if ($Backup)
        {
            Copy-Item -Path $File -Destination "$(Split-Path -Leaf $File).bck"
        }

        Set-Content -Path $File -Value $raw
    }
}
