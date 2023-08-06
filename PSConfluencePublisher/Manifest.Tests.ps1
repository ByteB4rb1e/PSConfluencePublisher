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
                     return '{"pages":[], "attachments": []}'
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
                     return '{"pagges":[], "attsdachments": []}'
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
                     'pages' = @()
                     'attachments' = @()
                 }

                 Mock Set-Content {
                    Should -Invoke -CommandName 'Set-Content' -Exactly -Times 1

                    $Path | Should -Be 'foobar.x'

                    $Value | Should -Be ($mockManifest | ConvertTo-JSON)
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
                     'pagges' = @()
                     'attachments' = @()
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
                     'pages' = @()
                     'attachments' = @()
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
                     'pages' = @()
                     'attachments' = @()
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


Describe 'New-PagesManifestIndex' `
{
    Context 'default' `
    {
        BeforeEach `
        {
             $mockManifest = @(
                 @{
                     'Title' = 'foobar0'
                 },
                 @{
                     'Title' = 'foobar1'
                 }
             )
        }

        It 'from pipeline' `
        {
            $index = New-PagesManifestIndex -Manifest $mockManifest

            $index.foobar0 | Should -Be 0

            $index.foobar1 | Should -Be 1
        }

        It 'from pipeline' `
        {
            $index = ,$mockManifest | New-PagesManifestIndex

            $index.foobar0 | Should -Be 0

            $index.foobar1 | Should -Be 1
        }
    }
}


Describe 'New-AttachmentsManifestIndex' `
{
    Context 'default' `
    {
        BeforeEach `
        {
             $mockManifest = @(
                 @{
                     'ContainerPageTitle' = 'foobar0'
                     'Name' = 'attachment0'
                 },
                 @{
                     'ContainerPageTitle' = 'foobar1'
                     'Name' = 'attachment1'
                 }
             )
        }

        It 'from parameter' `
        {
            $index = New-AttachmentsManifestIndex -Manifest $mockManifest

            $index."foobar0:attachment0" | Should -Be 0

            $index."foobar1:attachment1" | Should -Be 1
        }

        It 'from pipeline' `
        {
            $index = ,$mockManifest | New-AttachmentsManifestIndex

            $index."foobar0:attachment0" | Should -Be 0

            $index."foobar1:attachment1" | Should -Be 1
        }
    }
}


Describe 'Get-AncestralPageGenerationCache' `
{
    Context 'default' `
    {
        BeforeEach `
        {
            $mockManifest = @(
                @{
                    'Title' = 'foobar0'
                },
                @{
                    'Title' = 'foobar1'
                    'AncestorTitle' = 'foobar0'
                }
            )

            $mockIndex = @{
                'foobar0' = 0
                'foobar1' = 1
            }
        }

        It 'selects single operation by title' `
        {
            $result = New-AncestralPageGenerationCache `
                -Title 'foobar0' `
                -Manifest $mockManifest `
                -Index $mockIndex

            $result.Count | Should -Be 1

            $result.foobar0 | Should -Be 0
        }

        It 'automatically builds index' `
        {
            $result = New-AncestralPageGenerationCache `
                -Title 'foobar0' `
                -Manifest $mockManifest `

            $result.Count | Should -Be 1

            $result.foobar0 | Should -Be 0
        }

        It 'accepts a pipeline' `
        {
            $result = New-AncestralPageGenerationCache `
                -Manifest $mockManifest `
                -Index $mockIndex

            $result.Count | Should -Be 2

            $result.foobar0 | Should -Be 0

            $result.foobar1 | Should -Be 1
        }
    }


    Context 'more complex' `
    {
        BeforeEach `
        {
            $mockManifest = @(
                @{
                    'Title' = 'foobar0'
                },
                @{
                    'Title' = 'foobar4'
                    'AncestorTitle' = 'foobar3'
                },
                @{
                    'Title' = 'foobar1'
                    'AncestorTitle' = 'foobar0'
                },
                @{
                    'Title' = 'foobar3'
                    'AncestorTitle' = 'foobar2'
                },
                @{
                    'Title' = 'foobar2'
                    'AncestorTitle' = 'foobar1'
                }
            )

            $mockIndex = @{
                'foobar0' = 0
                'foobar1' = 2
                'foobar2' = 4
                'foobar3' = 3
                'foobar4' = 1
            }
        }

        It 'uses index' `
        {
            $result = New-AncestralPageGenerationCache `
                -Manifest $mockManifest `
                -Index $mockIndex

            $result.foobar0 | Should -Be 0

            $result.foobar1 | Should -Be 1

            $result.foobar2 | Should -Be 2
            
            $result.foobar3 | Should -Be 3
            
            $result.foobar4 | Should -Be 4
        }
    }
}


Describe 'Optimize-PagesManifest' `
{
    Context 'default' `
    {
        BeforeEach `
        {
            $mockManifest = @(
                @{
                    'Title' = 'foobar0'
                },
                @{
                    'Title' = 'foobar4'
                    'AncestorTitle' = 'foobar3'
                },
                @{
                    'Title' = 'foobar1'
                    'AncestorTitle' = 'foobar0'
                },
                @{
                    'Title' = 'foobar3'
                    'AncestorTitle' = 'foobar2'
                },
                @{
                    'Title' = 'foobar5'
                    'AncestorTitle' = 'foobar2'
                },
                @{
                    'Title' = 'foobar2'
                    'AncestorTitle' = 'foobar1'
                }
            )

            $mockGenerationCache = @{
                'foobar0' = 0
                'foobar1' = 1
                'foobar2' = 2
                'foobar3' = 3
                'foobar4' = 4
                'foobar5' = 3
            }
        }

        It 'from parameter' `
        {
            Optimize-PagesManifest `
                -Manifest $mockManifest `
                -Lo 0 `
                -Hi ($mockManifest.Count - 1) `
                -GenerationCache $mockGenerationCache

            $mockManifest[0].Title | Should -Be 'foobar0'

            $mockManifest[1].Title | Should -Be 'foobar1'

            $mockManifest[2].Title | Should -Be 'foobar2'

            $mockManifest[3].Title | Should -Be 'foobar5'

            $mockManifest[4].Title | Should -Be 'foobar3'

            $mockManifest[5].Title | Should -Be 'foobar4'
        }
    }
}
