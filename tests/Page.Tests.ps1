#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"


If ((Get-Module -Name 'Pester').Version.Major -ge 5)
{
    BeforeAll `
    {
        Import-Module "$PSScriptRoot/../src/PSConfluencePublisher.psd1"
    }
}

Else
{
    Import-Module "$PSScriptRoot/../src/PSConfluencePublisher.psd1" -Force
}


Describe 'New-Page' `
{
    BeforeEach `
    {
        $defaultMockContent = 'foobar content'

        $defaultMockSpaceName = 'testitest'

        $defaultMockTitle = 'foobar'

        $defaultMockPageMeta = @{
            'Title' = $defaultMockTitle
            'Ref' = 'pages/320okffs.xml'
        }

        $defaultMockManifest = @(
            $defaultMockPageMeta
        )

        $mockIndex = @{
            $defaultMockTitle = 0
        }

        Mock -ModuleName 'Page' Get-Content {
            $defaultMockContent
        }

        Mock -ModuleName 'Page' Get-PersonalAccessToken {
            '01234567890123456789'
        }

        Mock -ModuleName 'Page' Invoke-WebRequest {
            $Uri | Should -Be 'https://confluence.contoso.com/rest/api/content'

            $body_ = $Body | ConvertFrom-JSON

            $body_.type | Should -Be 'page'

            $body_.body.storage.representation | Should -Be 'storage'

            $body_.body.storage.value | Should -Be (
                $defaultMockContent | Out-String
            )

            $body_.space.key | Should -Be $defaultMockSpaceName

            # TODO: write proper parameter filters, so that we can reuse this
            # mock with more thorough/deep assertions on properties
            # $body_.title | Should -Be $defaultMockTitle

            @{
                'Content' = '{"Id": "123", "version": {"number": 1}}'
            }
        }

        Mock -ModuleName 'Page' Get-StringHash {
            @{
                'Hash' = 'NOTAREALHASH'
            }
        }
    }

    Context 'default' `
    {
        It 'accepts parameterized input' `
        {
            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title $defaultMockTitle `
                          -Manifest $defaultMockManifest `
                          -Index $mockIndex

            $result | Should -Be $defaultMockPageMeta

            $result.Id | Should -Be '123'

            $result.Version | Should -Be 1

            $result.Hash | Should -Be ('NOTAREALHASH')
        }

        It 'accepts pipeline input' `
        {
            $result = $defaultMockManifest | New-Page `
                                          -Host 'confluence.contoso.com' `
                                          -Space $defaultMockSpaceName `
                                          -Title $defaultMockTitle `
                                          -Index $mockIndex

            $result | Should -Be $defaultMockPageMeta

            $result.Id | Should -Be '123'

            $result.Version | Should -Be 1

            $result.Hash | Should -Be ('NOTAREALHASH')
        }
    }

    Context 'single page publishing (page title provided)' `
    {
        BeforeEach `
        {
            $secondaryMockPageMeta = @{
                'Title' = 'foobar2'
                'Ref' = 'pages/320okffs.xml'
            }

            $mockManifest = @(
                $defaultMockPageMeta,
                $secondaryMockPageMeta
            )

            $mockIndex = @{
                $defaultMockTitle = 0
                'foobar2' = 1
            }
        }

        It 'expands unary array to first item' `
        {
            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title $defaultMockTitle `
                          -Manifest $mockManifest `
                          -Index $mockIndex

            $result.Count | Should -Be 1

            $result | Should -Be $defaultMockPageMeta

            $result.Id | Should -Be '123'

            $result.Version | Should -Be 1

            $result.Hash | Should -Be ('NOTAREALHASH')
        }

        It 'expands unary array to second item' `
        {
            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title 'foobar2' `
                          -Manifest $mockManifest `
                          -Index $mockIndex

            $result | Should -Be $secondaryMockPageMeta

            $result.Count | Should -Be 1

            $result.Id | Should -Be '123'

            $result.Version | Should -Be 1

            $result.Hash | Should -Be ('NOTAREALHASH')
        }
    }

    Context 'reference' `
    {
        BeforeEach `
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
        }

        It 'does not output page metadata, if not strict' `
        {

            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title $defaultMockTitle `
                          -Manifest $mockManifest `
                          -Index $mockIndex

            $result | Should -Be $null
        }

        It 'throws an error, if strict' `
        {
            {
                $result = New-Page `
                              -Host 'confluence.contoso.com' `
                              -Space $defaultMockSpaceName `
                              -Title $defaultMockTitle `
                              -Manifest $mockManifest `
                              -Index $mockIndex
                              -Strict
            } | Should -Throw
        }
    }

    Context 'already published' `
    {
        BeforeEach `
        {
            $mockPageMeta = @{
                'Title' = $defaultMockTitle
                'Ref' = 'pages/320okffs.xml'
                'Id' = '123'
            }

            $mockManifest = @(
                $mockPageMeta
            )

            $mockIndex = @{
                $defaultMockTitle = 0
            }
        }

        It 'skips publishing' `
        {
            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title $defaultMockTitle `
                          -Manifest $mockManifest `
                          -Index $mockIndex

            $result | Should -Be $mockPageMeta

            (
                $result | Get-Member -Name 'Version'
            ) | Should -Be $null

            Should -Invoke -CommandName 'Invoke-WebRequest' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 0
        }
    }

    Context 'multi-page publishing' `
    {
        BeforeEach `
        {
            $secondaryMockPageMeta = @{
                'Title' = 'foobar2'
                'Ref' = 'pages/320okffs.xml'
            }

            $tertiaryMockPageMeta = @{
                'Title' = 'foobar3'
                'Ref' = 'pages/320okffs.xml'
            }

            $mockManifest = @(
                $defaultMockPageMeta,
                $secondaryMockPageMeta,
                $tertiaryMockPageMeta
            )

            $mockIndex = @{
                $defaultMockTitle = 0
                'foobar2' = 1
                'foobar3' = 2
            }
        }

        It 'handles all pages in manifest' `
        {
            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Manifest $mockManifest `
                          -Index $mockIndex

            $result.Count | Should -Be 3

            Should -Invoke -CommandName 'Invoke-WebRequest' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 3
        }

        It 'returns correct count for single item arrays' `
        {
            $result = New-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Manifest $defaultMockManifest `
                          -Index $mockIndex

            $result.Count | Should -Be 1

            Should -Invoke -CommandName 'Invoke-WebRequest' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 1
        }
    }
}


Describe 'Update-Page' `
{
    BeforeEach `
    {
        $defaultMockContent = 'foobar content'

        $defaultMockSpaceName = 'testitest'

        $defaultMockTitle = 'foobar'

        $defaultMockPageMeta = @{
            'Title' = $defaultMockTitle
            'Ref' = 'pages/320okffs.xml'
            'Id' = 123
            'Version' = 2
        }

        $defaultMockManifest = @(
            $defaultMockPageMeta
        )

        $mockIndex = @{
            $defaultMockTitle = 0
        }

        Mock -ModuleName 'Page' Get-Content {
            $defaultMockContent
        }

        Mock -ModuleName 'Page' Get-PersonalAccessToken {
            '01234567890123456789'
        }

        # TODO: write proper parameter filters, so that we can reuse this
        # mock with more thorough/deep assertions on properties
        Mock -ModuleName 'Page' Invoke-WebRequest {
            # $Uri | Should -Be 'https://confluence.contoso.com/rest/api/content'

            $body_ = $Body | ConvertFrom-JSON

            $body_.type | Should -Be 'page'

            $body_.body.storage.representation | Should -Be 'storage'

            $body_.body.storage.value | Should -Be (
                $defaultMockContent | Out-String
            )

            $body_.space.key | Should -Be $defaultMockSpaceName

            # $body_.title | Should -Be $defaultMockTitle

            @{
                'Content' = 'DONT CARE ABOUT THE RESPONSE CONTENT'
            }
        }

        Mock -ModuleName 'Page' Get-StringHash {
            @{
                'Hash' = 'NOTAREALHASH'
            }
        }
    }

    Context 'default' `
    {
        It 'accepts parameterized input' -Tag Now `
        {
            $result = Update-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title $defaultMockTitle `
                          -Manifest $defaultMockManifest `
                          -Index $mockIndex

            $result | Should -Be $defaultMockPageMeta
        }

        It 'accepts pipeline input' `
        {
            $result = $defaultMockManifest | Update-Page `
                                          -Host 'confluence.contoso.com' `
                                          -Space $defaultMockSpaceName `
                                          -Title $defaultMockTitle `
                                          -Index $mockIndex

            $result | Should -Be $defaultMockPageMeta
        }
    }
}


Describe 'Publish-Page' `
{
    BeforeEach `
    {
        $defaultMockSpaceName = 'foobar-space'

        $defaultMockTitle = 'foobar'

        $defaultMockManifest = @(
            @{},
            @{},
            @{}
        )

        $defaultMockIndex = @{}

        Mock -ModuleName 'Page' New-Page {
            $defaultMockManifest
        }

        Mock -ModuleName 'Page' Update-Page {
            $defaultMockManifest
        }
    }

    Context 'default' -Tag 'Now' `
    {
        It 'passes everything properly' `
        {
            $result = Publish-Page `
                          -Host 'confluence.contoso.com' `
                          -Space $defaultMockSpaceName `
                          -Title $defaultMockTitle `
                          -Index $defaultMockIndex `
                          -Manifest $defaultMockManifest

            $result | Should -Be $defaultMockManifest

            Should -Invoke -CommandName 'New-Page' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 1 `

            Should -Invoke -CommandName 'Update-Page' `
                -ModuleName 'Page' `
                -Exactly `
                -Times 1 `
        }
    }
}
