#! /usr/bin/pwsh

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

$ErrorView = "NormalView"

Import-Module Pester -ErrorAction Stop -Force

Invoke-Pester -Configuration @{
    'Debug' = @{
        'ShowFullErrors' = $false
        'ShowNavigationMarkers' = $false
        'WriteDebugMessagesFrom' = 'CodeCoverage'
    }
    'Output' = @{
        'Verbosity' = 'Normal'
    }
    'Run' = @{
        'Path' = Join-Path $PSScriptRoot '..' 'tests' '*'
        'Exit' = $true
        'PassThru' = $true
    }
    'CodeCoverage' = @{
        'Enabled' = $true
        'Path' = Join-Path $PSScriptRoot '..' 'src' '*'
        'OutputPath' = Join-Path $PSScriptRoot '..' 'test-reports' `
                                               'coverage.xml'
    }
    'TestResult' = @{
        'Enabled' = $true
        'OutputPath' = Join-Path $PSScriptRoot '..' 'test-reports' 'testResults.xml'
    }
}

