# Palworld 1.0.2.100993 Compatibility Validation

## Scope

This record documents post-release compatibility testing of the unchanged
published `RE-UE4SS-Linux linux-v0.1.1` package against a newer native
Linux Palworld Dedicated Server executable.

| Component | Identity |
|---|---|
| Validation ID | `20260730T031746Z` |
| Palworld version | `1.0.2.100993` |
| Steam build ID | `24445026` |
| Unreal Engine | `5.1.1` |
| Distribution | Fedora Linux 43 |
| Architecture | x86-64 |
| PalServer SHA-256 | `f1d8ced330d8933bf077040dbf62c11f9ebf79d299369d16ba736ea36afda01b` |
| PalServer ELF build ID | `12db0eec6678474d` |
| RE-UE4SS-Linux release | `linux-v0.1.1` |
| Release-candidate workflow run | `30429172898` |
| Loader SHA-256 | `342ade2dbfd53cba6d33755b9c7cee1ebe6c4b5946a34dac23a65cca32eff5f1` |
| Loader ELF build ID | `506501ae9a2ff891e913c509e7dee1495bd62403` |

## Results

| Validation | Result |
|---|---|
| Updated PalServer identity captured | Pass |
| Binary changed from `1.0.2.100933` | Yes |
| ELF build ID changed from `1.0.2.100933` | Yes |
| Stale `user_home_t` label detected | Pass |
| Strict preflight rejected stale label with status 8 | Pass |
| `restorecon` restored `palworld_ue4ss_exec_t` | Pass |
| Strict preflight after relabel | Pass |
| Exact published loader mapped into PalServer | Pass |
| Required signature resolution | Pass |
| Empty-mod startup and stability | Pass |
| Full existing mod-set startup | Pass |
| BaseRadiusImproved hook registration | Pass |
| BaseRadiusImproved authority callback | Pass |
| Client connection | Pass |
| World load | Pass |
| BaseRadiusImproved observed in client | Pass |
| Process domain `palworld_ue4ss_t` | Pass |
| UDP 8212 and 27016 listeners | Pass |
| Graceful process-group shutdown | Pass |
| Surviving process | None |
| Surviving test listeners | None |
| SELinux AVCs | None |
| Crash evidence | None |
| Source or signature changes required | No |
| Overall compatibility | Pass |

## SELinux observation

The Steam update replaced the server executable and reset its file label to
`user_home_t`. The `linux-v0.1.1` launcher correctly blocked startup before
UE4SS hook installation. After `restorecon` restored the persistent
`palworld_ue4ss_exec_t` type, the process transitioned into
`palworld_ue4ss_t` and completed runtime testing without AVCs.

## Evidence provenance

Raw console logs, audit output, and runtime artifacts are retained outside
the repository. The reviewed result summaries had these SHA-256 identities:

| Evidence summary | SHA-256 |
|---|---|
| Preflight result | `317d616aab0e36ec56cbd2f3ac93d698294996ef8ecd52ded7a4f73e1ec9baf8` |
| Empty-mod result | `c570a9158435c03c90df0c5d50b4b68f71decc0beb2c7d7a8e79ee7add412771` |
| Full-mod result | `1acc635a58067a652a6a752fb6a39eeb8808943089c7d1a32ad9d3ec53bab456` |

No proprietary Palworld binary, generated runtime archive, crash archive,
or private credential is included in this repository record.
