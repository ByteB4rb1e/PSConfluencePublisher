#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'PSConfluencePublisher.psd1') -Force

    $mockHost = 'confluence.contoso.com'

    $mockPat = '01234567890123456789'
}


Describe 'Register-PersonalAccessToken' `
{
    BeforeEach {
        Initialize-PersonalAccessTokenStore
    }

    Context 'Parameterized' {

        It 'throws no exception' {
            Register-PersonalAccessToken -Host $mockHost -Token $mockPat
        }
    }

    Context 'Shorthand' {

        It 'throws no exception' {
            Register-PersonalAccessToken $mockHost $mockPat
        }
    }
}


Describe 'Get-PersonalAccessToken' `
{
    BeforeEach {
        Initialize-PersonalAccessTokenStore
    }

    Context 'Parameterized' {

        It 'gets an existing PAT' {

            Register-PersonalAccessToken -Host $mockHost -Token $mockPat

            Get-PersonalAccessToken -Host $mockHost | Should -Be $mockPat
        }

        It 'requires PAT to exist' {

            {Get-PersonalAccessToken -Host $mockHost} | Should -Throw
        }
    }

    Context 'Shorthand' {

        It 'throws no exception' {

            Register-PersonalAccessToken -Host $mockHost -Token $mockPat

            Get-PersonalAccessToken $mockHost | Should -Be $mockPat
        }
    }
}