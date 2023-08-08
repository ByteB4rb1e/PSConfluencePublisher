# CONTRIBUTION GUIDELINES

This document describes guidelines for contributing source code (and other)
data to this repository, as well as principles for working.

## Source Code Management (Git)

### Versioning

This project uses [semantic versioning (SemVer)](https://semver.org/) for 
software  release versioning.

Should the Git HEAD have a tag with a SemVer string prefixed with v as a name,
and the Git stage be empty, this version MUST then be obliged to in all build
processes as a release.

However should the Git stage not be empty, or the HEAD not be tagged, the patch 
version MUST BE incremented by supplying *dev* suffixed with a unique random 
string.

### Branching

Modular branches (e.g. *foo/bar*, not *foo*) MUST correspond to an issue inside 
an issue tracker.

Therefore, all source code changes for features MUST be tracked in a Git branch
`feat/$ISSUE`, wheras `$ISSUE` is the id of the corresponding issue inside
the issue tracker. Bugs are tracked under `bugfix/$ISSUE` and hotfixes are
tracked under `hotfix/$ISSUE`.

### Releasing

Features and bugfix branches must be (squash) merged into the Git branch `dev` 
for releasing.

Preparing a release as this program’s maintainer requires one to create a 
`release/$SEMVER` branch and have the release tested by whoever
opened the issue, or feature. If bugs are found, they must be tracked inside
the issue tracker and once concluded must be integrated into the
`release/$SEMVER` branch and tested through whoever opened the bug. Once
the bug is resolved, the `release/$SEMVER` branch MUST be (fast-forward)
merged into the `dev` branch. The release can only be concluded if the HEAD
of the `release/$SEMVER` branch is tagged with a SemVer version string.

Afterwards the `release/$SEMVER` branch MUST be merged (no fast-forward) into
the `master` Git branch.

Each release (irrelevant of it being a major, minor, or patch release) must
have a dedicated changelog release note.

Copy the release note of the previous release from
`doc/changelogs/%Y%M%D %d.%d.%d.rst` and increment the date and version of
the filename, as well as chapter title. Next make sure to stick to the
Keep-A-Changelog format and describe the changes only through *Fixed*,
*Changed*, *Added* sections.

Afterwards, include the release note inside the changelog and add a link to the 
web page of the Git repository tag.

### Commit Messages

This project uses
[conventional commit messages](https://www.conventionalcommits.org/en/v1.0.0/).

Do write your messages for humans. Humor and Emojis are welcomed, as long as 
commit messages are well-formed and understandable.

Additionally, the following rules apply.

Well-known commit types SHOULD be used, which includes:

* `feat` (e.g. adding a new functionality)
* `fix` (e.g. making something work correctly)
* `style` (e.g. prefixing all class names in a namespace)
* `chore` (e.g. routine bump of dependency version)
* `refactor` (e.g. changing code without changing the behavior)
* `docs` (e.g. updating a description like a docstring/comment of something)

### Commit signatures

All commits MUST be PGP-signed. See
[7.4 Git Tools - Signing Your Work](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)
in the Git SCM documentation for more information on configuring Git clients to 
use GnuPG for signing Git commits.
