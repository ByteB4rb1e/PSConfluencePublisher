#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1') -Force

}

AfterAll {
    
}


Describe 'Get-Manifest' `
{

    Context 'Parameterized' {

        It 'throws no exception' {

            InModuleScope Connection {

                 Mock Get-PersonalAccessToken {'01234567890123456789'}

                 Mock Invoke-WebRequest {
                     return @{
                         'Content' = "{'type': 'known'}"
                         'StatusCode' = 200
                     }
                 }

                 Test-Connection -Host 'confluence.contoso.com'
            }
        }

        It 'detects anonymous authentication' {

            InModuleScope Connection {

                 Mock Get-PersonalAccessToken {'01234567890123456789'}

                 Mock Invoke-WebRequest {
                     return @{
                         'Content' = "{'type': 'anonymous'}"
                         'StatusCode' = 200
                     }
                 }

                 {Test-Connection -Host 'confluence.contoso.com'} | Should -Throw
            }
        }

        It 'detects non 200 status codes' {

            InModuleScope Connection {

                 Mock Get-PersonalAccessToken {'01234567890123456789'}

                 Mock Invoke-WebRequest {
                     return @{
                         'Content' = "{'type': 'anonymous'}"
                         'StatusCode' = 500
                     }
                 }

                 {Test-Connection -Host 'confluence.contoso.com'} | Should -Throw
            }
        }
    }
}
