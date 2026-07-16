# Palworld Native C++ Mod Loading Result

## Environment

| Component | Value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Loader baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Loader SHA-256 | `1f1459b01ff3de75ea637097c0a1ef7bf141e2b2b93369351b22c16105ec1f73` |
| Native mod SHA-256 | `43375b12a3b44ef03cab74801ebd9adcef86525f2b5821911e5f31fa6e25f701` |
| Source SHA-256 | `d056caa5c72ce5d5eaf3c232f807fb0ec8bc3370c39afee8c055aaa1b4fe70f8` |
| Build script SHA-256 | `b0b53ae2bffef8eb95a45fa55b77be33a5884d3032be004aa4e9105e7bdc60af` |
| Audit archive SHA-256 | `1bdd24f13bdc602dffe535242ec58e144260f0b049bd07cd9cea24b8a9a8c5d1` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

The native shared object exported exactly:

```text
start_mod
uninstall_mod
```

It declared a runtime dependency on the tested `libUE4SS.so`, and all
relocations resolved successfully.

Observed lifecycle:

```text
[NullPrismNativeAcceptance] start_mod export
[NullPrismNativeAcceptance] constructor
[NullPrismNativeAcceptance] on_cpp_mods_loaded
[NullPrismNativeAcceptance] on_unreal_init
[NullPrismNativeAcceptance] StaticFindObject result=valid
[NullPrismNativeAcceptance] RESULT=PASS
[NullPrismNativeAcceptance] on_program_start
```

The module was visibly mapped into the live PalServer process from:

```text
Mods/NullPrismNativeAcceptance/dlls/main.so
```

The runtime also verified:

- UDP ports 8212 and 27016 were active.
- PalServer ran in the scoped `palworld_ue4ss_t` SELinux domain.
- No native-loader error was emitted.
- No nonempty crash file was generated.
- No SELinux AVC was generated.
- No isolated process or test listener survived shutdown.

## Explicit teardown behavior

Ordinary host-process shutdown did not emit:

```text
uninstall_mod export
destructor
```

Both exports were present and resolved successfully, but normal PalServer
termination did not traverse UE4SS's explicit mod-uninstall path. The operating
system reclaimed the module as part of host-process termination.

This behavior is recorded separately from the successful native discovery,
loading, lifecycle-callback, Unreal-access, and shutdown results.
