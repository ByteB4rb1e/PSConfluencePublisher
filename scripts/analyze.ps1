#! /usr/bin/pwsh

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

$ErrorView = "NormalView"

$basePath = Join-Path $PSScriptRoot '..'

Import-Module PSScriptAnalyzer -ErrorAction Stop -Force

Invoke-ScriptAnalyzer `
    -Path (Join-Path -Path $basePath 'src') `
    -Settings PSGallery `
    -Recurse
