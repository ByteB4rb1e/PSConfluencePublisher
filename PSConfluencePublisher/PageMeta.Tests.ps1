#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1')
}


Describe 'Get-PageMetaCache' `
{
    Context 'default' `
    {
        It 'uses index' `
        {
            $mockPageMeta = @{
               'Title' = 'foobar'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            $mockIndex = @{
                'foobar' = 0
            }

            $meta = Get-PageMetaCache `
                        -Title 'foobar' `
                        -Manifest $mockManifest `
                        -Index $mockIndex

            $meta | Should -Be $mockPageMeta
        }

        It 'returns page meta when title exists' `
        {
            $mockPageMeta = @{
               'Title' = 'foobar'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            $meta = Get-PageMetaCache `
                        -Title 'foobar' `
                        -Manifest $mockManifest

            $meta | Should -Be $mockPageMeta
        }

        It 'returns null, if page with supplied title does not exist' `
        {
            $mockManifest = @(
                @{}
            )

            $meta = Get-PageMetaCache `
                        -Title 'foobar' `
                        -Manifest $mockManifest

            $meta | Should -Be $null
        }
    }
}


Describe 'Get-PageMeta' `
{
    Context 'default' `
    {
        BeforeAll `
        {
            Mock -ModuleName 'PageMeta' Get-PersonalAccessToken {
                '012345678901234567890'
            }
        }

        It 'returns cache when page id present' `
        {
            $mockPageMeta = @{
                'Title' = 'foobar'
                'Id' = '0123456789'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Mock -ModuleName 'PageMeta' Get-PageMetaCache {
                $mockPageMeta
            }

            $meta = Get-PageMeta `
                        -Host 'foobar' `
                        -Title 'foobar' `
                        -Space 'foobar' `
                        -Manifest $mockManifest

            $meta | Should -Be $mockPageMeta

            Should -Invoke -CommandName 'Get-PageMetaCache' `
                -ModuleName 'PageMeta' `
                -Exact `
                -Times 1
        }

        It 'gets a page id remotely if there is exactly one result' `
        {
            $mockPageMeta = @{
                'Version' = 'version'
                'Hash' = 'hash'
                'Ref' = 'ref'
            }

            Mock -ModuleName 'PageMeta' Get-PageMetaCache {
                $mockPageMeta
            }

            Mock -ModuleName 'PageMeta' Update-PageMeta {
                $Id | Should -Be '123'

                $Version | Should -Be 9

                $Title | Should -Be 'foobar'

                $mockPageMeta
            }

            Mock -ModuleName 'PageMeta' Invoke-WebRequest {
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

            Should -Invoke 'Get-PageMetaCache' `
                -ModuleName 'PageMeta' `
                -Exactly `
                -Times 1

            Should -Invoke 'Invoke-WebRequest' `
                -ModuleName 'PageMeta' `
                -Exactly `
                -Times 1

            Should -Invoke 'Update-PageMeta' `
                -ModuleName 'PageMeta' `
                -Exactly `
                -Times 1
        }

        It 'throws an exception, if there is more than one result' `
        {
            Mock -ModuleName 'PageMeta' Invoke-WebRequest {
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
            } | Should -Throw 'more than one result for query*'
        }

        It 'throws an exception, if there is no result' `
        {
            Mock -ModuleName 'PageMeta' Invoke-WebRequest {
                @{
                    'Content' = '{"results": []}'
                }
            }

            $result = Get-PageMeta `
                          -Host 'confluence.contoso.com' `
                          -Title 'foobar' `
                          -Space 'foobar' `
                          -Manifest @{'Pages'= {}}

            $result | Should -Be $null
        }
    }
}


Describe 'Update-PageMeta' `
{
    Context 'default' `
    {
        It 'fails, if page meta index does not exist' `
        {
            {
                Update-PageMeta `
                    -Id '0123456789' `
                    -Title 'foobar' `
                    -Manifest @{} 
            } | Should -Throw
        }

        It 'updates minimal' `
        {
            $mockPageMeta = @{
                'Title' = 'foobar'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            $pageMeta = Update-PageMeta `
                            -Title 'foobar' `
                            -Id '0123456789' `
                            -Manifest $mockManifest

            $mockPageMeta.Id | Should -Be '0123456789'
        }

        It 'updates extended' `
        {
            $mockPageMeta = @{
                'Title' = 'foobar'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Update-PageMeta `
                -Title 'foobar' `
                -Id 'pageId' `
                -Version 9001 `
                -AncestorTitle 'ancestorTitle' `
                -Hash 'hash' `
                -Manifest $mockManifest

            $mockPageMeta.Id | Should -Be 'pageId'

            $mockPageMeta.Version | Should -Be 9001

            $mockPageMeta.AncestorTitle | Should -Be 'ancestorTitle'

            $mockPageMeta.Hash | Should -Be 'hash'
        }
    }
}
