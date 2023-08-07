#! /usr/bin/pwsh

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

$ErrorView = "NormalView"

$basePath = Join-Path $PSScriptRoot '..'

@(
    'dist',
    'test-reports'
) | ForEach {
    $path = Join-Path $basePath $_

    If (-Not (Test-Path $path)) {return}

    Write-Host "rm: $(Resolve-Path $path)"

    Remove-Item -Recurse -Force ($path)
}
