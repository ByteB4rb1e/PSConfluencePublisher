#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1') -Force
}

Describe 'Get-StringHash' `
{
    Context 'default' `
    {
        It 'works' `
        {
             $result = Get-StringHash 'foobar'
 
             $result.Hash | Should -Be (
                'C3AB8FF13720E8AD9047DD3946' + `
                '6B3C8974E592C2FA383D4A3960714CAEF0C4F2')
        }
    }
}
