#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module "$PSScriptRoot/../src/PSConfluencePublisher.psd1"
}


Describe 'Get-PageMeta' `
{
    BeforeAll `
    {
        Mock -ModuleName 'PageMeta' Get-PersonalAccessToken {
            '012345678901234567890'
        }
    }

    Context 'default' `
    {

        It 'uses index' `
        {
            $mockPageMeta = @{
                'Title' = 'foobar'
                'Id' = '0123456789'
            }

            $mockManifest = @(
                @{},
                $mockPageMeta
            )

            $mockIndex = @{
                'foobar' = 1
            }

            $meta = Get-PageMeta `
                        -Host 'foobar' `
                        -Title 'foobar' `
                        -Space 'foobar' `
                        -Index $mockIndex `
                        -Manifest $mockManifest

            $meta | Should -Be $mockPageMeta
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

            $meta = Get-PageMeta `
                        -Host 'foobar' `
                        -Title 'foobar' `
                        -Space 'foobar' `
                        -Manifest $mockManifest

            $meta | Should -Be $mockPageMeta
        }
    }

    Context 'locally cached' `
    {
        BeforeAll `
        {
            $mockManifest = @(
                @{
                    'Title' = 'page0'
                    'Id' = 'id0'
                },
                @{
                    'Title' = 'page1'
                    'Id' = 'id1'
                },
                @{
                    'Title' = 'page2'
                    'Id' = 'id2'
                }
            )
        }

        It 'from parameter' `
        {
            $meta = Get-PageMeta `
                        -Host 'foobar' `
                        -Space 'foobar' `
                        -Manifest $mockManifest

            $meta.Count | Should -Be 3
        }

        It 'from pipeline' `
        {
            $meta = $mockManifest | Get-PageMeta `
                        -Host 'foobar' `
                        -Space 'foobar'

            $meta.Count | Should -Be 3
        }
    }

    Context 'locally cached' `
    {
        BeforeAll `
        {
            $mockManifest = @(
                @{
                    'Title' = 'page0'
                    'Id' = 'id0'
                },
                @{
                    'Title' = 'page1'
                },
                @{
                    'Title' = 'page2'
                    'Id' = 'id2'
                }
            )

            Mock -ModuleName 'PageMeta' Invoke-WebRequest {
                @{
                    'Content' = '{"results": [{"id": "remoteid", "_expandable": {"version": 1}}]}'
                }
            }
        }

        It 'only gets remote if necesary' `
        {
            $meta = Get-PageMeta `
                        -Host 'foobar' `
                        -Space 'foobar' `
                        -Manifest $mockManifest

            Should -Invoke -CommandName Invoke-WebRequest `
                -ModuleName 'PageMeta' `
                -Exactly `
                -Times 1

            $meta.Count | Should -Be 3

            $meta[0].Id | Should -Be 'id0'

            $meta[0].Version | Should -Be $null

            $meta[1].Id | Should -Be 'remoteid'

            $meta[1].Version | Should -Be 1
        }

        It 'forcefully gets remote' `
        {
            $meta = Get-PageMeta `
                        -Host 'foobar' `
                        -Space 'foobar' `
                        -Force `
                        -Manifest $mockManifest

            Should -Invoke -CommandName Invoke-WebRequest `
                -ModuleName 'PageMeta' `
                -Exactly `
                -Times 3

            $meta.Count | Should -Be 3

            $meta[0].Id | Should -Be 'remoteid'

            $meta[0].Version | Should -Be 1

            $meta[1].Id | Should -Be 'remoteid'

            $meta[1].Version | Should -Be 1

            $meta[2].Id | Should -Be 'remoteid'

            $meta[2].Version | Should -Be 1
        }
    }
}

