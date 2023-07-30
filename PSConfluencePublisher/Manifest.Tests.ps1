#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1') -Force
}

AfterAll {
    
}


Describe 'Get-Manifest' `
{
    Context 'Parameterized' `
    {
        It 'can successfully validate against the schema' `
        {
            InModuleScope Manifest `
            {
                 Mock Get-Content {
                     return '{"pages":{}, "attachments": {}}'
                 }

                 #mocking Get-Content, therefore file name can be bogus
                 Get-Manifest 'foobar.x'
            }
        }

        It 'throws on schema mismatch' `
        {
            InModuleScope Manifest `
            {
                 Mock Get-Content {
                     return '{"pagges":{}, "attsdachments": {}}'
                 }

                 #mocking Get-Content, therefore file name can be bogus
                 {Get-Manifest 'foobar.x'} | Should -Throw
            }
        }
    }
}


Describe 'Set-Manifest' `
{
    Context 'noBackup' `
    {
        It 'can successfully validate against the schema' `
        {
            InModuleScope Manifest `
            {
                 $mockManifest = @{
                     'pages' = @{}
                     'attachments' = @{}
                 }

                 Mock Set-Content {
                    Should -Invoke -CommandName 'Set-Content' -Exactly -Times 1

                    $args[1] | Should -Be 'foobar.x'

                    $args[3] | Should -Be ($mockManifest | ConvertTo-JSON)
                 }

                 #mocking Get-Content, therefore file name can be bogus
                 Set-Manifest `
                    -Manifest $mockManifest `
                    -File 'foobar.x'
            }
        }

        It 'declines setting invalid schema' `
        {
            InModuleScope Manifest `
            {
                 $mockManifest = @{
                     'pagges' = @{}
                     'attachments' = @{}
                 }

                 #mocking Get-Content, therefore file name can be bogus
                 {
                     Set-Manifest `
                         -Manifest $mockManifest `
                         -File 'foobar.x'
                 } | Should -Throw
            }
        }
    }

    Context 'Backup' `
    {
        It 'creates a backup when it should' `
        {
            InModuleScope Manifest `
            {
                 $mockManifest = @{
                     'pages' = @{}
                     'attachments' = @{}
                 }

                 Mock Set-Content {
                    #FIXME: the scope is completely wrong
                    Should -Invoke -CommandName 'Set-Content' -Exactly -Times 1
                 }

                Mock Copy-Item {
                    #FIXME: the scope is completely wrong
                    Should -Invoke -CommandName 'Copy-Item' -Exactly -Times 1 `

                    $Path | Should -Be 'foobar.x'

                    $Destination | Should -Be 'foobar.x.bck'
                } 

                 #mocking Get-Content, therefore file name can be bogus
                 Set-Manifest `
                    -Manifest $mockManifest `
                    -File 'foobar.x' `
                    -Backup $true
            }
        }

        It 'handles paths outside of the current working directory correctly' `
        {
            InModuleScope Manifest `
            {
                 $mockManifest = @{
                     'pages' = @{}
                     'attachments' = @{}
                 }

                 Mock Set-Content {
                    #FIXME: the scope is completely wrong
                    Should -Invoke -CommandName 'Set-Content' -Exactly -Times 1
                 }

                Mock Copy-Item {
                    #FIXME: the scope is completely wrong
                    Should -Invoke -CommandName 'Copy-Item' -Exactly -Times 1 `

                    $Path | Should -Be 'foo/bar/foobar.x'

                    $Destination | Should -Be 'foo/bar/foobar.x.bck'
                }

                 #mocking Get-Content, therefore file name can be bogus
                 Set-Manifest `
                    -Manifest $mockManifest `
                    -File 'foo/bar/foobar.x' `
                    -Backup $true
            }
        }
    }
}
