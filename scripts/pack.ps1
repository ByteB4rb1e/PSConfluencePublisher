#! /usr/bin/pwsh

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

$ErrorView = "NormalView"

$basePath = Join-Path $PSScriptRoot '..'

nuget pack (Join-Path $basePath 'PSConfluencePublisher.nuspec') `
    -OutputDirectory (Join-Path $basePath 'dist')
