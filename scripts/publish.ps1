#! /usr/bin/pwsh

Param(
    [Parameter(Mandatory)] [String] $ApiKey,
    [Parameter()] [String] $Source = 'https://www.powershellgallery.com/api/v2/package'
)

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

$ErrorView = "NormalView"

$basePath = Join-Path $PSScriptRoot '..'


Get-Item -Path (Join-Path -Path $basePath 'dist' '*.nupkg') | ForEach {

    nuget push $_ -Source $Source -ApiKey $ApiKey
}
