#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1')
}


Describe 'Test-Connection' `
{
    Context 'default' {
        BeforeAll `
        {
            Mock -ModuleName 'Connection' Get-PersonalAccessToken {
                '01234567890123456789'
            }
        }

        It 'throws no exception' {
            Mock -ModuleName 'Connection' Invoke-WebRequest {
                @{
                    'Content' = "{'type': 'known'}"
                    'StatusCode' = 200
                }
            }

            Test-Connection -Host 'confluence.contoso.com'

            Should -Invoke -CommandName 'Get-PersonalAccessToken' `
                -ModuleName 'Connection' ` `
                -Exact `
                -Times 1

            Should -Invoke -CommandName 'Invoke-WebRequest' `
                -ModuleName 'Connection' ` `
                -Exact `
                -Times 1
        }

        It 'detects anonymous authentication' {
            Mock -ModuleName 'Connection' Invoke-WebRequest {
                @{
                    'Content' = "{'type': 'anonymous'}"
                    'StatusCode' = 200
                }
            }

            {Test-Connection -Host 'confluence.contoso.com'} | Should -Throw

            Should -Invoke -CommandName 'Get-PersonalAccessToken' `
                -ModuleName 'Connection' ` `
                -Exact `
                -Times 1

            Should -Invoke -CommandName 'Invoke-WebRequest' `
                -ModuleName 'Connection' ` `
                -Exact `
                -Times 1
        }

        It 'detects non 200 status codes' {
            Mock -ModuleName 'Connection' Invoke-WebRequest {
                @{
                    'Content' = "{'type': 'anonymous'}"
                    'StatusCode' = 500
                }
            }

            {Test-Connection -Host 'confluence.contoso.com'} | Should -Throw

            Should -Invoke -CommandName 'Get-PersonalAccessToken' `
                -ModuleName 'Connection' ` `
                -Exact `
                -Times 1

            Should -Invoke -CommandName 'Invoke-WebRequest' `
                -ModuleName 'Connection' ` `
                -Exact `
                -Times 1
        }
    }
}
