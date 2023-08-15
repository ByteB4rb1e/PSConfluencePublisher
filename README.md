# PSConfluencePublisher

This program is a standalone publisher component for the 
[victorykit-xconfluencebuilder](https://bitbucket.org/victorykit/xconfluencebuilder) 
Sphinx extension. 

It consumes, a JSON-formatted manifest of a *Sphinx build* dump generated by 
the `victorykit-xconfluencebuilder` and unidirectionally synchronizes 
pages, page ancestry, and attachments.

Publishing is supported via the Confluence Server REST API through 
[Personal Access Token (PAT) authorization](https://confluence.atlassian.com/enterprise/using-personal-access-tokens-1026032365.html).

## (Interchange) Manifest

The manifest consists of a *Pages* manifest and an *Attachments* manifest, which
store metadata on pages and attachments. Even though the *Pages* manifests 
(represented as array object) is expected to have the appropriate order for
publishing, where the oldest ancestral generation of pages is published before 
the youngest, this isn't trusted and the pages manifest is ordered in-place, 
through a Hoare partitioned Quick-Sort via the ``Optimize-PagesManifest`` 
function.

The manifest is treated as read/write and used for storing additional metadata
to reduce the amount of remote data retrieval. This includes hashing of page and
attachments content in addition to tracking publishing versions and remote ids.
Through a JSONSchema, it is made sure that the manifest stays consistent for
interchange with the original manifest producer system
(`victorykit-xconfluencebuilder`).

## Usage

You may install this PowerShell module via
[PowerShellGallery](https://www.powershellgallery.com/packages/victorykit.PSConfluencePublisher).

```
PS > Install-Module victorykit.PSConfluencePublisher
```

Alternatively, you can import the module from source. In order to do that, 
clone the 
[Git repository](https://bitbucket.org/victorykit/psconfluencepublisher/src)
, change into the directory and import it.

```
PS> git clone git@bitbucket.org:victorykit/psconfluencepublisher.git
```

```
PS> # universal import statement compatible with PowerShell Core & Desktop
PS> Import-Module "src/victorykit.PSConfluencePublisher.psd1"
```

An implementation reference is provided through `samples/default`.

You will need the hostname (or IP address) of a Confluence instance, a Personal
Access Token (PAT) and the name of a space.

The reference implementation uses manifest data generated by the sample 
reference implementation of *xconfluencebuilder*, which are 2 (ancestraly 
related) pages with 2 attachments (JPEG images, more importantly JPEG cat 
images).

To execute the sample reference implementation, run 
`pwsh samples/default/run.ps1`

```
$ pwsh samples/default/run.ps1 \
    -Hostname 'confluence.contoso.com' \
    -Space 'MS' \
    -PersonalAccessToken `THISISNOTAREALTOKEN`
initializing manifest...
DEBUG: Initialize-Manifest: loading manifest...
DEBUG: Initialize-Manifest: creating pages manifest index...
DEBUG: Initialize-Manifest: creating ancestral page generation cache...
DEBUG: Initialize-Manifest: sorting pages manifest...
DEBUG: Initialize-Manifest: recreating pages manifest index...
DEBUG: Initialize-Manifest: creating attachments manifest index...
initializing and testing connectivity...
Verified connectivity (confluence.contoso.com).                                                  
fetching pages metadata...
DEBUG: Get-PageMetadata: `Default Sample~`: no remote, using (partial) local                   
DEBUG: Get-PageMetadata: `Cats`: no remote, using (partial) local                              
publishing pages (2)...
Update-Page: `Default Sample~`: unknown page id. Skipping.
Update-Page: `Cats`: unknown page id. Skipping.
New-Page: `Default Sample~`: creating
New-Page: `Cats`: creating                                                                     
fetching attachments metadata...                                                               
DEBUG: Get-AttachmentMetadata: `pexels-just-a-couple-photos-3777622.jpg`: no remote, using (partial) local
DEBUG: Get-AttachmentMetadata: `pexels-sami-aksu-14356302.jpg`: no remote, using (partial) local
DEBUG: Get-AttachmentMetadata: `objects.inv`: no remote, using (partial) local                 
publishing attachments (3)...
Update-Attachment: `pexels-just-a-couple-photos-3777622.jpg`: unknown attachment id. Skipping.
Update-Attachment: `pexels-sami-aksu-14356302.jpg`: unknown attachment id. Skipping.
Update-Attachment: `objects.inv`: unknown attachment id. Skipping.
New-Attachment: `pexels-just-a-couple-photos-3777622.jpg`: creating
New-Attachment: `pexels-sami-aksu-14356302.jpg`: creating                                      
New-Attachment: `objects.inv`: creating                                                        
dumping manifest to filesystem...
```

On the next invocation, only changed content will be updated:

```
$ pwsh samples/default/run.ps1 \
    -Hostname 'confluence.contoso.com' \
    -Space 'MS' \
    -PersonalAccessToken `THISISNOTAREALTOKEN`
initializing manifest...
DEBUG: Initialize-Manifest: loading manifest...
DEBUG: Initialize-Manifest: creating pages manifest index...
DEBUG: Initialize-Manifest: creating ancestral page generation cache...
DEBUG: Initialize-Manifest: sorting pages manifest...
DEBUG: Initialize-Manifest: recreating pages manifest index...
DEBUG: Initialize-Manifest: creating attachments manifest index...
initializing and testing connectivity...
Verified connectivity (confluence.contoso.com).                                                                           
fetching pages metadata...
DEBUG: Get-PageMeta: `Default Sample~`: using locally cached metadata (789703435)
DEBUG: Get-PageMeta: `Cats`: using locally cached metadata (789703436)
publishing pages (2)...
DEBUG: Update-Page: `Default Sample~`: skipping, no content changes
DEBUG: Update-Page: `Cats`: skipping, no content changes
DEBUG: New-Page: `Default Sample~`: skipping, already published (789703435)
DEBUG: New-Page: `Cats`: skipping, already published (789703436)
fetching attachments metadata...
DEBUG: Get-AttachmentMeta: `pexels-just-a-couple-photos-3777622.jpg`: using locally cached metadata (789703437)
DEBUG: Get-AttachmentMeta: `pexels-sami-aksu-14356302.jpg`: using locally cached metadata (789703438)
DEBUG: Get-AttachmentMeta: `objects.inv`: using locally cached metadata (789703439)
publishing attachments (3)...
DEBUG: Update-Attachment: `pexels-just-a-couple-photos-3777622.jpg`: skipping, no content changes
DEBUG: Update-Attachment: `pexels-sami-aksu-14356302.jpg`: skipping, no content changes
DEBUG: Update-Attachment: `objects.inv`: skipping, no content changes
DEBUG: New-Attachment: `pexels-just-a-couple-photos-3777622.jpg`: skipping, already published (789703437)
DEBUG: New-Attachment: `pexels-sami-aksu-14356302.jpg`: skipping, already published (789703438)
DEBUG: New-Attachment: `objects.inv`: skipping, already published (789703439)
dumping manifest to filesystem...
```

Content can still be forcefully updated by supplying a ``-Force`` switch:

```
$ pwsh samples/default/run.ps1 \
    -Hostname 'confluence.contoso.com' \
    -Space 'MS' \
    -PersonalAccessToken `THISISNOTAREALTOKEN` \
    -Force
```




For the current moment, the top-level/root page will be applied to the root of
the Confluence space. Manually move the page (as necessary)  after initial 
publishing, recurring publishments will not require you to do so.

## Compatibility

This program is compatible with the following Microsoft PowerShell runtimes:

- Microsoft PowerShell Desktop >=5
- Microsoft PowerShell Core >=7

## Runtime Dependencies

This program has no runtime dependencies and is purely written in the PowerShell
scripting language, with some built-in dependencies towards .NET Core 2 (present
in all PowerShell editions).

On PowerShell Desktop, however, it is necessary to obtain the 
`Microsoft.PowerShell.Utility` module for JSON schema verification of the 
manifest. Whether that's possible for PowerShell Desktop; We do not know. 
Should the aforementioned module not be present, JSON validation is  disabled.

## Debugging

To display debug messages, set 
[$DebugPreference](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.3#debugpreference)
to `Continue`, or `Inquire` in your shell's *Global* scope.

## Static Code Analysis

This program requires
[PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules)
for static code analysis.

Execute `pwsh scripts/analyze.ps1` to do a static code analysis.

## Testing

This program requires [Pester](https://pester.dev/) to execute it's test suite.

The test suite aims to be executable under most circumstances. We've been 
dropping usage of Pester v5 functionalities so that it works with Pester down 
to version 3, since Pester v3 is available in PowerShell (5) Desktop by default.
Due to the security mechanisms implemented in PowerShell Desktop, installing the
Pester v5 module may not be feasible for some.

Execute `pwsh scripts/test.ps1` to run the entire test suite.

## Packaging & Publishing

This program does not adhere to Microsoft's Best-Practices of publishing
PowerShell modules, in the sense of that it does not use the *PowerShellGet*
module to do so and uses the plain `nuget` CLI instead.

This program requires [nuget
CLI](https://learn.microsoft.com/en-us/nuget/install-nuget-client-tools). Be
aware that the `dotnet nuget` CLI may not be sufficient on some platforms.

Execute `pwsh scripts/pack.ps1` to create the nuget package.

Execute `pwsh scripts/publish.ps1` to publish the nuget package to
[PowerShellGallery](https://www.powershellgallery.com).
