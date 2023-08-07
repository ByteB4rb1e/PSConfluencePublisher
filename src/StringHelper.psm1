#!/usr/bin/env pwsh

function Get-StringHash
{
    <#
        .SYNOPSIS
            Get hash value of a string

        .DESCRIPTION
            The Get-StringHash function is just a wrapper around the
            Get-FileHash function and utilizes a stream for providing said
            function with proper input values.

        .OUTPUTS
            Same as the Get-FileHash function

        .EXAMPLE
            Get-StringHash 'foobar' -Algorithm 'SHA256'
    #>
    Param(
        [Parameter(Mandatory, Position = 0)] [String] $InputString,
        [Parameter()] [String] $Algorithm = 'SHA256'
    )

    Begin
    {
        $stream = [IO.MemoryStream]::New()

        $writer = [IO.StreamWriter]::New($stream)

        $writer.Write($InputString)

        $writer.Flush()

        $stream.Position = 0
    }

    Process
    {
         Get-FileHash -InputStream $stream -Algorithm $Algorithm
    }
}
