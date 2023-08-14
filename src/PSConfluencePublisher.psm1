$ErrorActionPreference = "Stop"


function Initialize-Manifest
{
    <#
        .SYNOPSIS
            Initialize a manifest (in-memory)

        .DESCRIPTION
            This function initializes a manifest by loading a serialized
            manifest from the filesystem, generating indexes and sorting the
            pages manifest, so that the ancestral relation defines the order in
            which pages will be published.
    #>
    Param(
        # path of manifest to load
        [Parameter(Mandatory)] [String] $Path
    )

    Begin
    {
        $literalPath = Resolve-Path -Path $Path
    }

    Process
    {
        Write-Debug 'Initialize-Manifest: loading manifest...'

        $manifest = Get-Manifest $literalPath

        Write-Debug 'Initialize-Manifest: creating pages manifest index...'

        $pagesManifestIndex = New-PagesManifestIndex -Manifest $manifest.Pages

        Write-Debug (
            'Initialize-Manifest: creating ancestral page generation cache...'
        )

        $ancestralGenerationCache = New-AncestralPageGenerationCache `
                                        -Manifest $manifest.Pages `
                                        -Index $pagesManifestIndex

        Write-Debug 'Initialize-Manifest: sorting pages manifest...'

        Optimize-PagesManifest `
            -Manifest $manifest.Pages `
            -Lo 0 `
            -Hi ($manifest.Pages.Count - 1) `
            -GenerationCache $ancestralGenerationCache | Out-Null

        Write-Debug 'Initialize-Manifest: recreating pages manifest index...'

        $pagesManifestIndex = New-PagesManifestIndex -Manifest $manifest.Pages

        Write-Debug (
            'Initialize-Manifest: creating attachments manifest index...'
        )

        $attachmentsManifestIndex = New-AttachmentsManifestIndex `
                                        -Manifest $manifest.Attachments
    }

    End
    {
        @{
            'Path' = $literalPath
            'Manifest' = $manifest
            'Index' = @{
                'Pages' = $pagesManifestIndex
                'Attachments' = $attachmentsManifestIndex
            }
        } 
    }
}


function Initialize-Connection
{
    <#
        .SYNOPSIS
            initialize a connection to a Confluence instance

        .DESCRIPTION
            This function registers a Personal Access Token (locally) and checks
            connectivity to a Confluence instance. It also verifies, that the
            Personal Access Tokens authenticates.

        .NOTES
            TODO: extend verification to also verify that write access to the 
            provided space is granted.
    #>
    Param(
        # hostname (or IP address) of Confluence instance
        [Parameter(Mandatory)] [String]$Host,
        # id of Confluence space
        [Parameter(Mandatory)] [String]$Space,
        # personal access token
        [Parameter(Mandatory)] [String]$PersonalAccessToken
    )

    Process
    {
        Register-PersonalAccessToken `
            -Host $Host `
            -Token $PersonalAccessToken | Out-Null

        Test-Connection -Host $Host | Out-Null
    }

    End
    {
        @{
            'Host' = $Host
            'Space' = $Space
        }
    }
}


function Publish-Pages
{
    <#
        .SYNOPSIS
            Publish pages to Confluence instance

        .DESCRIPTION
            This function publishes all (or one) pages as defined in the pages
            manifest.

            Since pipelining is supported within the low-level functions, this
            function is basically just a wrapper.

        .NOTE
            TODO: Investigate on how we can pass-through the manifest as to
            retain pipeline functionality throughout. Currently it is broken,
            since the manifest isn't passed as a pieline input object from the
            top (which is this function).
    #>
    Param(
        # connection object created through Initialize-Connection
        [Parameter(Mandatory)] [Collections.Hashtable]$Connection,
        # manifest object created through Initialize-Manifest
        [Parameter(Mandatory)] [PSCustomObject]$Manifest,
        # 
        [Parameter()] [Switch]$Strict,
        # 
        [Parameter()] [Switch]$Force,
        # title of page to be published
        [Parameter()] [String]$Title
    )

    Process
    {
        Publish-Page `
            -Host $Connection.Host `
            -Space $Connection.Space `
            -Title $Title `
            -Index $Manifest.Index.Pages `
            -Manifest $Manifest.Manifest.Pages `
            -Strict:$Strict `
            -Force:$Force | Out-Null
    }
}


function Publish-Attachments
{
    <#
        .SYNOPSIS
            Publish attachments to Confluence instance

        .DESCRIPTION
            This function publishes all (or one) attachments as defined in the 
            attachments manifest.

            Since pipelining is supported within the low-level functions, this
            function is basically just a wrapper.
    #>
    Param(
        # connection object created through Initialize-Connection
        [Parameter(Mandatory)] [Collections.Hashtable]$Connection,
        # manifest object created through Initialize-Manifest
        [Parameter(Mandatory)] [PSCustomObject]$Manifest,
        # 
        [Parameter()] [Switch]$Strict,
        # 
        [Parameter()] [Switch]$Force,
        # name of attachment to be published
        [Parameter()] [String]$Name
    )

    Process
    {
        Publish-Attachment `
            -Host $Connection.Host `
            -Space $Connection.Space `
            -Name $Name `
            -Manifest $Manifest.Manifest.Attachments `
            -Index $Manifest.Index.Attachments `
            -PagesManifest $Manifest.Manifest.Pages `
            -PagesIndex $Manifest.Index.Pages `
            -Strict:$Strict `
            -Force:$Force | Out-Null
    }
}
