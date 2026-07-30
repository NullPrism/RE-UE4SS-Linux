# Linux Compatibility Matrix

## Latest validated target

### Palworld Dedicated Server

| Component | Validated value |
|---|---|
| Game | Palworld |
| Game version | 1.0.2.100993 |
| Steam build ID | 24445026 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Distribution | Fedora Linux 43 |
| Imported Linux baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Release | `linux-v0.1.1` |
| Validation type | Post-release validation of the unchanged published package |
| PalServer SHA-256 | `f1d8ced330d8933bf077040dbf62c11f9ebf79d299369d16ba736ea36afda01b` |
| PalServer ELF build ID | `12db0eec6678474d` |
| Loader SHA-256 | `342ade2dbfd53cba6d33755b9c7cee1ebe6c4b5946a34dac23a65cca32eff5f1` |
| Loader ELF build ID | `506501ae9a2ff891e913c509e7dee1495bd62403` |
| Loading method | Process-scoped launcher using `LD_PRELOAD` |
| Scoped SELinux entrypoint type | `palworld_ue4ss_exec_t` |
| Scoped SELinux process domain | `palworld_ue4ss_t` |

## Palworld 1.0.2.100993 post-release validation

| Capability | Status |
|---|---|
| Published `linux-v0.1.1` loader identity unchanged | Pass |
| Stale SELinux host-label rejection | Pass |
| Persistent-context recovery with `restorecon` | Pass |
| Required signature resolution | Pass |
| Empty-mod startup | Pass |
| Existing Lua mod startup | Pass |
| BaseRadiusImproved hook registration | Pass |
| BaseRadiusImproved authority callback | Pass |
| Client connection and world load | Pass |
| Process-scoped launcher | Pass |
| Scoped SELinux domain transition | Pass |
| Operation without global `execheap` | Pass |
| Operation without new SELinux AVCs | Pass |
| Crash evidence | None |
| Graceful process-group shutdown | Pass |
| Palworld or UE4SS signature changes required | No |

The Steam update replaced `PalServer-Linux-Shipping`, changing both its
SHA-256 and ELF build ID and resetting its file type to `user_home_t`. The
`linux-v0.1.1` strict SELinux preflight correctly rejected startup with
status 8. Applying the persistent file-context mapping with `restorecon`
restored `palworld_ue4ss_exec_t`, after which the server entered
`palworld_ue4ss_t` and completed empty-mod and full-mod validation without
crashes or SELinux AVCs.

See the complete
[Palworld 1.0.2.100993 validation record](../../validation/runtime/palworld-1.0.2.100993/RESULT.md).

## Original `linux-v0.1.1` release-acceptance target

| Component | Validated value |
|---|---|
| Game version | 1.0.2.100933 |
| Steam build ID | 24370498 |
| PalServer SHA-256 | `d16b4d840a30dc3f467fe1059a0088ddb08a4b513cc45150767cba1785867d30` |
| PalServer ELF build ID | `c339de6590a6a669` |
| Release | `linux-v0.1.1` |
| Runtime acceptance source | Exact release source and packaged identities recorded in `RELEASE-MANIFEST.txt` |

The `1.0.2.100933` update replaced the server executable and caused it to
receive the default `user_home_t` type. The process consequently remained
in `unconfined_t`, where SELinux denied executable heap memory used by a
PolyHook trampoline. Restoring the persistent `palworld_ue4ss_exec_t`
context allowed the expected transition into `palworld_ue4ss_t` and
resolved the fault without changing Unreal signatures or hook targets.

## Previous prerelease target

The `linux-v0.1.0` prerelease was accepted against:

| Component | Validated value |
|---|---|
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| PalServer SHA-256 | `788649fa1592160faa7bcf07ccd16d474ebeaae954717bc32284b5a43028d8e7` |
| PalServer ELF build ID | `7f7e167407984ec3` |
| Final acceptance matrix | 36 fresh-process cycles |
| Runtime acceptance source | `linux-v0.1.0` tag and `RELEASE-MANIFEST.txt` |

The corresponding detailed acceptance records remain under `validation/`.

## Limitations

- Compatibility evidence applies only to explicitly tested combinations.
- Do not unload UE4SS with `dlclose`.
- Stop the host process to unload the loader.
- Normal host-process shutdown did not invoke native mod `uninstall_mod` or
  the C++ destructor during validation.
- Native private C++ members are not automatically exposed as reflected Lua
  properties.
- Existing third-party Linux mod compatibility remains under evaluation.
- Dependency commits are not yet guaranteed to be reachable through stable
  public submodule remotes.
