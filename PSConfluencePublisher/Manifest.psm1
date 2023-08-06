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
            $raw = Get-Content $File | Out-String
        }

        catch
        {
            Write-Debug $_

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
            $baseDir = Split-Path $File

            $baseName = "$(Split-Path -Leaf $File).bck"

            #FIXME: this should be handled without an explicit condition
            if ($baseDir)
            {
                $path = Join-Path $baseDir $baseName
            }

            else
            {
                $path = $baseName
            }

            Copy-Item -Path $File -Destination $path
        }

        Set-Content -Path $File -Value $raw
    }
}


function New-AncestralPageGenerationCache {
    <#
        .SYNOPSIS
            Calculate the numeric ancestral generation of a page

        .DESCRIPTION
            The Get-AncestralPageGeneration calculates a numeric ancestral
            generation of a page, which is used for sorting.

            The index required as input can be retrieved through the 
            New-PagesManifestIndex function.

        .EXAMPLES
            $generation = Get-AncestralPageGeneration `
                              -Title 'foobar4' `
                              -Manifest @() `
                              -Index @{}
    #>
    Param(
        # Pages manifest
        [Parameter(Mandatory)] [Array] $Manifest,
        # Title of page to calculate generation of
        [Parameter()] [String] $Title,
        # Index for lookup of page metadata manifest item position
        [Parameter()] [Collections.Hashtable] $Index
    )

    Begin
    {
        $cache = @{}

        If (-Not $Index)
        {
            Write-Debug "rebuilding index"

            $Index = ,$Manifest | New-PagesManifestIndex
        }
    }

    Process
    {
        ForEach ($pageMeta in $Manifest)
        {
            $generation = 0

            $pageMeta = $Title ? $Manifest[$Index.$Title] : $pageMeta

            $ancestor = $pageMeta.AncestorTitle

            $pageMeta_ = $pageMeta

            While ($ancestor)
            {
                $generation += 1

                $pageMeta_ = $Manifest[$Index."$($pageMeta_.AncestorTitle)"]

                $ancestor = $pageMeta_.AncestorTitle
            }

            $cache[$pageMeta.Title] = $generation

            if ($Title) {Break}
        }
    }

    End {$cache}
}


function Optimize-PagesManifest
{
    <#
        .SYNOPSIS
            Sort Pages Manifest in accordance with the pages ancestry

        .DESCRIPTION
            The Optimize-PagesManifest function sorts a Pages manifest in
            accordance with the pages ancestry. This makes sure that an ancestor
            is already published, before its descendant is published.

            The sorting is done with a quick-sort algorithm, using the Hoare
            partitioning scheme.

            Older/lower ancestral generations take precedence over
            higher/younger ones. Syblings within a generation are treated 
            as LIFO, where the youngest (last) has precedence over the oldest
            (fist).

        .EXAMPLE
            $manifest Optimize-PagesManifest -Manifest ,@()

            or 

            $manifest = ,@() | Optimize-PagesManifest

        .NOTES
            whichever system generates the manifest should already output the
            array in the correct order, however it is not wise to depend upon
            this.
    #>
    Param(
        [Parameter(Mandatory)] [Array] $Manifest,
        [Parameter(Mandatory)] [Int] $Lo,
        [Parameter(Mandatory)] [Int] $Hi,
        # cache for storing the numeric ancestral generation of pages
        [Parameter(Mandatory)] [Collections.Hashtable] $GenerationCache
    )

    Process
    {
        $pivotPageMeta = $Manifest[($Lo + $Hi) / 2]

        $pivot = $generationCache[$pivotPageMeta.Title]

        # left index
        $i = $Lo

        # right index
        $j = $Hi

        While($i -le $j)
        {
            # Move the left index to the right at least once and while
            # the element at the left index is less than the pivot
            While (
                $generationCache."$($Manifest[$i].Title)" -lt $pivot `
                -And `
                $i -lt $Hi
            )
            {
                $i += 1
            }

            # Move the right index to the left at least once and while
            # element at the right index is greater than the pivot
            While (
                $generationCache."$($Manifest[$j].Title)" -gt $pivot `
                -And `
                $j -gt $Lo
            )
            {
                $j -= 1
            }

            If ($i -le $j)
            {
                $tmp = $Manifest[$i]

                $Manifest[$i] = $Manifest[$j]

                $Manifest[$j] = $tmp

                $i += 1

                $j -= 1
            }

            If ($Lo -lt $j)
            {
                Optimize-PagesManifest `
                    -Manifest $Manifest `
                    -Lo $Lo`
                    -Hi $j `
                    -GenerationCache $GenerationCache
            }

            If ($i -lt $Hi)
            {
                Optimize-PagesManifest `
                    -Manifest $Manifest `
                    -Lo $i `
                    -Hi $Hi `
                    -GenerationCache $GenerationCache
            }
        }
    }
}


function New-PagesManifestIndex
{
    <#
        .SYNOPSIS
            Create an index of pages from a manifest

        .DESCRIPTION
            The New-PageIndex function builds a page index from a manifest
            for faster lookup of page metadata. The title of a page is used for
            indexing, since a page title is unique within a Confluence space.

        .INPUTS
            Manifest

        .OUTPUTS
            Returns a Hashtable, where the key of each key-value pair is the
            page title and attachment name, and the value is the index of the 
            array item within the Attachments porition of the manifest.

        .EXAMPLE
            New-PageIndex -Manifest @{}
    #>
    Param(
        [Parameter(Mandatory, ValueFromPipeline)] [Array] $Manifest
    )

    Process
    {
        $index = @{}

        For($i = 0; $i -lt $Manifest.Count; $i += 1)
        {
            $index[$Manifest[$i].Title] = $i
        }

        $index
    }
}


function New-AttachmentsManifestIndex
{
    <#
        .SYNOPSIS
            Create an index of page container attachments from a manifest

        .DESCRIPTION
            The New-AttachmentIndex function builds an attachment index from a 
            manifest for faster lookup of attachment metadata. The title of 
            the container page, including the attachment name a is used for
            indexing, since attachment names are unique within a container page.

        .INPUTS
            Manifest

        .OUTPUTS
            Returns a Hashtable, where the key of each key-value pair is the
            interpolation of the container page title and attachment name, and 
            the value is the index of the array item within the Attachments 
            porition of the manifest.

        .EXAMPLE
            New-AttachmentIndex -Manifest @{}
    #>
    Param(
        #manifest
        [Parameter(Mandatory, ValueFromPipeline)] [Array] $Manifest
    )

    Process
    {
        $index = @{}

        For($i = 0; $i -lt $Manifest.Count; $i += 1)
        {
            $key = "$($Manifest[$i].ContainerPageTitle):" + `
                   "$($Manifest[$i].Name)"

            $index[$key] = $i
        }

        $index
    }
}

