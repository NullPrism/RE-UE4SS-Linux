# RE-UE4SS Linux v0.1.1

This patch prerelease hardens the native Linux launcher and updates the
validated Palworld Dedicated Server target.

## Validated target

- Palworld Dedicated Server `1.0.2.100933`
- Steam build ID `24370498`
- Unreal Engine `5.1.1`
- Native x86-64 Linux server
- Fedora Linux 43 validation hosts
- PalServer SHA-256
  `d16b4d840a30dc3f467fe1059a0088ddb08a4b513cc45150767cba1785867d30`
- PalServer ELF build ID `c339de6590a6a669`
- Scoped SELinux entrypoint type `palworld_ue4ss_exec_t`
- Scoped SELinux process domain `palworld_ue4ss_t`

The exact release source commit, packaged loader identity, archive checksums,
and final acceptance evidence are recorded in the release manifest and package
metadata.

## Highlights

- Detect stale SELinux labels on the host executable before UE4SS startup.
- Add `UE4SS_SELINUX_PREFLIGHT` modes:
  - `off`
  - `warn`, which is the default
  - `strict`
- Add `UE4SS_EXPECTED_SELINUX_TYPE` for scoped SELinux deployments.
- Exit with status 8 in strict mode when the host executable has an unexpected
  SELinux type.
- Warn when common unsuitable default types such as `user_home_t` are detected.
- Document persistent `semanage fcontext` mappings.
- Document running `restorecon` after game updates and validation operations.
- Continue operating without enabling the global `execheap` boolean.
- Update the current compatibility target to Palworld `1.0.2.100933`.

## Incident resolved

The Palworld 1.0.2 update replaced `PalServer-Linux-Shipping` with a new inode.
The replacement received the default `user_home_t` SELinux type instead of the
persistent UE4SS entrypoint type.

The server consequently remained in `unconfined_t`, and SELinux denied
`execheap` when PolyHook attempted to make an EngineTick trampoline executable.
The server later faulted when execution entered the non-executable trampoline.

Restoring `palworld_ue4ss_exec_t` caused the expected transition into
`palworld_ue4ss_t`. The existing loader then started successfully with no new
SELinux AVCs.

No PatternSleuth signatures, Unreal member offsets, EngineTick targets, or
Palworld-specific hook definitions required changes.

## Launcher configuration

Scoped deployments can require the expected entrypoint type with:

    UE4SS_SELINUX_PREFLIGHT=strict
    UE4SS_EXPECTED_SELINUX_TYPE=palworld_ue4ss_exec_t

The launcher exits before installing runtime hooks when strict validation
fails. This replaces a delayed executable-memory fault with an immediate,
actionable diagnostic.

## Downloads

- `RE-UE4SS-Linux-0.1.1-x86_64.tar.gz`
- `RE-UE4SS-Linux-0.1.1-x86_64-debug.tar.gz`
- `RELEASE-MANIFEST.txt`
- Accompanying SHA-256 files

The runtime archive contains the loader, process-scoped launcher, settings,
bundled mod files, installation documentation, provenance metadata, and
internal checksums.

## Compatibility scope

This prerelease does not claim compatibility with every Unreal Engine game,
engine version, Linux distribution, or third-party UE4SS mod.

Compatibility applies only to combinations explicitly recorded in the Linux
compatibility matrix. Stop the host process to unload UE4SS; do not use
`dlclose`.
