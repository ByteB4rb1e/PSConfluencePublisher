#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1') -Force
}


AfterAll {
    
}


Describe 'Get-CachedPageMeta' `
{
    Context 'Parameterized' `
    {
        It 'returns page meta when title exists' `
        {
            $mockPageName = 'Testitest'

            $mockPageMeta = @{
                'foo' = 'bar'
            }

            $mockManifest = @{
                'pages' = @{
                    $mockPageName = $mockPageMeta
                }
            }

            $meta = Get-CachedPageMeta `
                        -Title $mockPageName `
                        -Manifest $mockManifest

            $meta | Should -Be $mockPageMeta
        }

        It 'returns null of title does not exist' `
        {
            $mockPageName = 'Testitest'


            $mockManifest = @{
                'pages' = @{}
            }

            $meta = Get-CachedPageMeta `
                        -Title $mockPageName `
                        -Manifest $mockManifest

            $meta | Should -Be $null
        }
    }
}


Describe 'Get-PageMeta' `
{
    Context 'Parameterized' `
    {
        It 'returns cache when present' `
        {
            InModuleScope Page `
            {
                $mockPageMeta = @{
                    'foo' = 'bar'
                }

                Mock Get-CachedPageMeta {
                    $mockPageMeta
                }

                $meta = Get-PageMeta `
                            -Host 'foobar' `
                            -Title 'foobar' `
                            -Space 'foobar' `
                            -Manifest @{}

                $meta | Should -Be $mockPageMeta
            }
        }

        It 'gets a page id remotely if there is exactly one result' `
        {
            InModuleScope Page `
            {
                $mockPageMeta = @{
                    'PageId' = 'page_id'
                    'Version' = 'version'
                    'Hash' = 'hash'
                    'Ref' = 'ref'
                }

                Mock Get-PersonalAccessToken {"012345678901234567890"}

                Mock Update-PageMeta {
                    #FIXME: wrong scope
                    Should -Invoke 'Update-PageMeta' -Exactly -Times 1

                    $PageId | Should -Be '123'

                    $Version | Should -Be 9

                    $Title | Should -Be 'foobar'

                    $mockPageMeta
                }

                Mock Invoke-WebRequest {
                    @{
                        'Content' = '{"results": [{"id": "123","_expandable":{"version": 9}}]}'
                    }
                }

                $meta = Get-PageMeta `
                            -Host 'confluence.contoso.com' `
                            -Title 'foobar' `
                            -Space 'foobar' `
                            -Manifest @{'Pages'= {}}

                $meta | Should -Be $mockPageMeta
            }
        }

        It 'throws an exception, if there is more than one result' `
        {
            InModuleScope Page `
            {
                Mock Get-PersonalAccessToken {"012345678901234567890"}

                Mock Invoke-WebRequest {
                    @{
                        'Content' = '{"results": [{}, {}]}'
                    }
                }

                {
                    Get-PageMeta `
                        -Host 'confluence.contoso.com' `
                        -Title 'foobar' `
                        -Space 'foobar' `
                        -Manifest @{'Pages'= {}}
                } | Should -Throw
            }
        }

        It 'throws an exception, if there is no result' `
        {
            InModuleScope Page `
            {
                Mock Get-PersonalAccessToken {"012345678901234567890"}

                Mock Invoke-WebRequest {
                    @{
                        'Content' = '{"results": [{}, {}]}'
                    }
                }

                {
                    Get-PageMeta `
                        -Host 'confluence.contoso.com' `
                        -Title 'foobar' `
                        -Space 'foobar' `
                        -Manifest @{'Pages'= {}}
                } | Should -Throw
            }
        }
    }
}


Describe 'Update-PageMeta' `
{
    Context 'Parameterized' `
    {
        It 'fails, if page meta index does not exist' `
        {
            {
                Update-PageMeta `
                    -PageId 'foobar' `
                    -Title 'foobar' `
                    -Manifest @{} 
            } | Should -Throw
        }

        It 'fails, if page title is not indexed' `
        {
            {
                Update-PageMeta `
                    -PageId 'foobar' `
                    -Title 'foobar' `
                    -Manifest @{'Pages' = @{}}
            } | Should -Throw
        }

        It 'updates minimal' `
        {
            $mockManifest = @{'Pages' = @{'foobar' = @{}}}

            Update-PageMeta `
                -Title 'foobar' `
                -PageId 'pageId' `
                -Manifest $mockManifest

            $mockManifest.Pages.foobar.PageId | Should -Be 'pageId'
        }

        It 'updates extended' `
        {
            $mockManifest = @{'Pages' = @{'foobar' = @{}}}

            Update-PageMeta `
                -Title 'foobar' `
                -PageId 'pageId' `
                -Version 9001 `
                -AncestorTitle 'ancestorTitle' `
                -Hash 'hash' `
                -Manifest $mockManifest

            $mockManifest.Pages.foobar.PageId | Should -Be 'pageId'

            $mockManifest.Pages.foobar.Version | Should -Be 9001

            $mockManifest.Pages.foobar.AncestorTitle | Should -Be 'ancestorTitle'

            $mockManifest.Pages.foobar.Hash | Should -Be 'hash'
        }
    }
}


Describe 'New-Page' `
{
    Context 'Parameterized' `
    {
        It 'fails, if page meta index does not exist' `
        {
            InModuleScope Page `
            {
                $mockManifest = @{
                    'Pages' = @{
                        'title' = @{
                            'Ref' = 'pages/320okffs.xml'
                        }
                    }
                }

                Mock Get-Content {
                    $Path | Should -Be 'pages/320okffs.xml'

                    'foobar'
                }

                Mock Get-PersonalAccessToken {
                    '01234567890123456789'
                }

                Mock Invoke-WebRequest {
                    $Uri | Should -Be 'https://confluence.contoso.com/rest/api/content'

                    $body_ = $Body | ConvertFrom-JSON

                    $body_.type | Should -Be 'page'

                    $body_.body.storage.representation | Should -Be 'storage'

                    $body_.body.storage.value | Should -Be 'foobar'

                    $body_.space.key | Should -Be 'testitest'

                    $body_.title | Should -Be 'title'

                    @{
                        'Content' = '{"Id": "123", "version": {"number": "1"}}'
                    }
                }

                New-Page `
                    -Host 'confluence.contoso.com' `
                    -Space 'testitest' `
                    -Title 'title' `
                    -Manifest $mockManifest
            }
        }
    }
}


Describe 'Update-Page' `
{
    Context 'Parameterized' `
    {
        It 'succeeds' `
        {
            InModuleScope Page `
            {
                $mockManifest = @{
                    'Pages' = @{
                        'mockTitle' = @{
                            'Ref' = 'pages/320okffs.xml'
                            'Id' = '0123456789'
                        }
                    }
                }

                Mock Get-Content {
                    $Path | Should -Be 'pages/320okffs.xml'

                    'foobar'
                }

                Mock Get-FileHash {
                    $Path | Should -Be 'pages/320okffs.xml'

                    $Algorithm | Should -Be 'SHA256'

                    @{
                        'Hash' = 'HASH0123456789'
                    }
                }

                Mock Get-PersonalAccessToken {
                    '01234567890123456789'
                }

                Mock Invoke-WebRequest {
                    $Uri | Should -Be 'https://confluence.contoso.com/rest/api/content/'

                    $body_ = $Body | ConvertFrom-JSON

                    $body_.type | Should -Be 'page'

                    $body_.body.storage.representation | Should -Be 'storage'

                    $body_.body.storage.value | Should -Be 'foobar'

                    $body_.space.key | Should -Be 'testitest'

                    $body_.title | Should -Be 'mockTitle'

                    @{
                        'Content' = '{"Id": "123", "version": {"number": 2}}'
                    }
                }

                Update-Page `
                    -Host 'confluence.contoso.com' `
                    -Space 'testitest' `
                    -Title 'mockTitle' `
                    -Manifest $mockManifest

                $mockMeta = $mockManifest.Pages.mockTitle

                $mockMeta.Hash | Should -Be 'HASH0123456789'

                $mockMeta.Version | Should -Be 2
            }
        }

        It 'skips, if hash unchanged' `
        {
            InModuleScope Page `
            {
                $mockManifest = @{
                    'Pages' = @{
                        'mockTitle' = @{
                            'Ref' = 'pages/320okffs.xml'
                            'Id' = '0123456789'
                            'Hash' = 'HASH0123456789'
                        }
                    }
                }

                Mock Get-Content {
                    $Path | Should -Be 'pages/320okffs.xml'

                    'foobar'
                }

                Mock Get-FileHash {
                    $Path | Should -Be 'pages/320okffs.xml'

                    $Algorithm | Should -Be 'SHA256'

                    @{
                        'Hash' = 'HASH0123456789'
                    }
                }

                Update-Page `
                    -Host 'confluence.contoso.com' `
                    -Space 'testitest' `
                    -Title 'mockTitle' `
                    -Manifest $mockManifest
            }
        }

        It 'fails, if page meta has no reference' `
        {
            InModuleScope Page `
            {
                $mockManifest = @{
                    'Pages' = @{
                        'mockTitle' = @{
                            'Id' = '0123456789'
                        }
                    }
                }

                {
                    Update-Page `
                        -Host 'confluence.contoso.com' `
                        -Space 'testitest' `
                        -Title 'mockTitle' `
                        -Manifest $mockManifest
                } | Should -Throw
            }
        }

        It 'fails, if page meta has no id' `
        {
            InModuleScope Page `
            {
                $mockManifest = @{
                    'Pages' = @{
                        'mockTitle' = @{
                            'Ref' = 'pages/320okffs.xml'
                        }
                    }
                }

                {
                    Update-Page `
                        -Host 'confluence.contoso.com' `
                        -Space 'testitest' `
                        -Title 'mockTitle' `
                        -Manifest $mockManifest
                } | Should -Throw
            }
        }
    }
}
