# Linux Release Policy

RE-UE4SS Linux uses a downstream-specific tag namespace:

    linux-vMAJOR.MINOR.PATCH

The `linux-` prefix distinguishes native Linux downstream releases from the
upstream UE4SS tags retained in this repository.

Release archives omit the tag prefix:

    RE-UE4SS-Linux-MAJOR.MINOR.PATCH-x86_64.tar.gz
    RE-UE4SS-Linux-MAJOR.MINOR.PATCH-x86_64-debug.tar.gz

## Release process

1. Select an exact source commit that has passed normal Linux CI.
2. Run the Linux Release Candidate workflow with that full commit and version.
3. Independently verify the downloaded archives on Fedora.
4. Confirm the packaged source identity and loader checksum.
5. Perform isolated live runtime acceptance when the loader identity has not
   already passed the applicable runtime suite.
6. Create an annotated `linux-vMAJOR.MINOR.PATCH` tag on the exact source commit.
7. Publish the already validated archives and checksum files in a GitHub
   Release.

Release publication does not rebuild the loader. The files attached to the
GitHub Release must be the exact files that passed candidate verification and
any required live runtime acceptance.

## Prereleases

Early Linux releases are published as GitHub prereleases while compatibility is
limited to explicitly recorded game, engine, distribution, and server-build
combinations.

A prerelease designation does not weaken package integrity requirements. Every
published archive must pass the same reproducible packaging, checksum,
relocation, metadata, and bundled-mod-default validation used for stable
packages.
