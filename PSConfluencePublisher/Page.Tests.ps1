#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1')
}


Describe 'New-Page' `
{
    Context 'default' `
    {
        BeforeAll `
        {
            Mock -ModuleName 'Page' Get-Content {
                'foobar content'
            }

            Mock -ModuleName 'Page' Get-PersonalAccessToken {
                '01234567890123456789'
            }
        }

        It 'succeeds' `
        {
            $mockPageMeta = @{
                'Title' = 'foobar'
                'Ref' = 'pages/320okffs.xml'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Mock -ModuleName 'Page' Get-PageMeta {
                $mockPageMeta
            }

            Mock -ModuleName 'Page' Update-PageMeta {
                $Id | Should -Be '123'

                $mockPageMeta.Id = '123'

                $mockPageMeta.Version = 1

                $mockPageMeta.Hash = 'NOTAREALHASH'

                $mockPageMeta
            }

            Mock -ModuleName 'Page' Invoke-WebRequest {
                $Uri | Should -Be 'https://confluence.contoso.com/rest/api/content'

                $body_ = $Body | ConvertFrom-JSON

                $body_.type | Should -Be 'page'

                $body_.body.storage.representation | Should -Be 'storage'

                $body_.body.storage.value | Should -Be 'foobar content'

                $body_.space.key | Should -Be 'testitest'

                $body_.title | Should -Be 'title'

                @{
                    'Content' = '{"Id": "123", "version": {"number": 1}}'
                }
            }

            New-Page `
                -Host 'confluence.contoso.com' `
                -Space 'testitest' `
                -Title 'title' `
                -Manifest $mockManifest

            $mockPageMeta.Id | Should -Be "123"

            $mockPageMeta.Version | Should -Be 1

            $mockPageMeta.Hash | Should -Be (
                'NOTAREALHASH'
            )

            Should -Invoke -CommandName 'Get-PageMeta' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 1

            Should -Invoke -CommandName 'Update-PageMeta' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 1
        }
    }
}


Describe 'Update-Page' `
{
    BeforeAll `
    {
        Mock -ModuleName 'Page' Get-Content {
            'foobar content'
        }

        Mock -ModuleName 'Page' Get-PersonalAccessToken {
            '01234567890123456789'
        }
    }

    Context 'default' `
    {
        BeforeAll `
        {
            Mock -ModuleName 'Page' Get-StringHash {
                @{
                    'Hash' = 'NOTAREALHASH'
                }
            }
        }

        It 'succeeds' `
        {
            $mockPageId = '0123456789'

            $mockPageMeta = @{
                'Title' = 'foobar'
                'Ref' = 'pages/320okffs.xml'
                'Id' = $mockPageId
                'Version' = 3
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Mock -ModuleName 'Page' Get-PageMeta {
                $mockPageMeta
            }

            Mock -ModuleName 'Page' Invoke-WebRequest {
                $Uri | Should -Be (
                    'https://confluence.contoso.com/rest/api/content/' + `
                    $mockPageId
                )

                $body_ = $Body | ConvertFrom-JSON

                $body_.type | Should -Be 'page'

                $body_.body.storage.representation | Should -Be 'storage'

                $body_.body.storage.value | Should -Be 'foobar content'

                $body_.space.key | Should -Be 'testitest'

                $body_.title | Should -Be 'foobar'

                $body_.version.number | Should -Be 4

                @{
                    'Content' = '{"Id": "123", "version": {"number": 4}}'
                }
            }

            Update-Page `
                -Host 'confluence.contoso.com' `
                -Space 'testitest' `
                -Title 'foobar' `
                -Manifest $mockManifest

            $mockPageMeta.Hash | Should -Be 'NOTAREALHASH'

            $mockPageMeta.Version | Should -Be 4
        }

        It 'skips, if hash unchanged' `
        {
            $mockPageId = '0123456789'

            $mockPageMeta = @{
                'Title' = 'foobar'
                'Ref' = 'pages/320okffs.xml'
                'Id' = $mockPageId
                'Version' = 3
                'Hash' = 'NOTAREALHASH'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Mock -ModuleName 'Page' Get-PageMeta {
                $mockPageMeta
            }

            Update-Page `
                -Host 'confluence.contoso.com' `
                -Space 'testitest' `
                -Title 'mockTitle' `
                -Manifest $mockManifest
        }

        It 'fails, if page meta has no reference' `
        {
            $mockPageId = '0123456789'

            $mockPageMeta = @{
                'Title' = 'foobar'
                'Id' = $mockPageId
                'Version' = 3
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Mock -ModuleName 'Page' Get-PageMeta {
                $mockPageMeta
            }

            {
                Update-Page `
                    -Host 'confluence.contoso.com' `
                    -Space 'testitest' `
                    -Title 'mockTitle' `
                    -Manifest $mockManifest
            } | Should -Throw "no reference to local content for page*"
        }

        It 'fails, if page meta has no id' `
        {
            $mockPageId = '0123456789'

            $mockPageMeta = @{
                'Title' = 'foobar'
                'Ref' = 'foo/bar'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            Mock -ModuleName 'Page' Get-PageMeta {
                $mockPageMeta
            }

            {
                Update-Page `
                    -Host 'confluence.contoso.com' `
                    -Space 'testitest' `
                    -Title 'mockTitle' `
                    -Manifest $mockManifest
            } | Should -Throw "no id for page*"
        }
    }
}
