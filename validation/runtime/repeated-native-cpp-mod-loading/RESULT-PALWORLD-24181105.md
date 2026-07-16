# Palworld Repeated Native C++ Mod Loading Result

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
| Native source SHA-256 | `d056caa5c72ce5d5eaf3c232f807fb0ec8bc3370c39afee8c055aaa1b4fe70f8` |
| Native build script SHA-256 | `b0b53ae2bffef8eb95a45fa55b77be33a5884d3032be004aa4e9105e7bdc60af` |
| Lifecycle harness SHA-256 | `06b8d5d2deaf79ae649cf94a23bbd51a35dda4b61ec297b9bc40f690c9034347` |
| Audit archive SHA-256 | `f196d339f9aed4967e480d188675819ce81887c05ba8418e98bdf9b865afa54e` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

Five complete fresh-process native C++ mod-loading cycles were performed.

Observed cycle matrix:

```text
cycle  startup_seconds  shutdown_seconds  shutdown_sigints  controller_status  native_markers  crash_files  avc_records  result
1      9                16                2                 130                7               0            0            PASS
2      9                16                2                 130                7               0            0            PASS
3      9                16                2                 130                7               0            0            PASS
4      9                16                2                 130                7               0            0            PASS
5      9                16                2                 130                7               0            0            PASS
```

Each cycle successfully observed:

```text
start_mod export
constructor
on_cpp_mods_loaded
on_unreal_init
StaticFindObject result=valid
RESULT=PASS
on_program_start
```

Every cycle also verified:

- the native module was mapped into PalServer;
- UDP ports 8212 and 27016 were active;
- PalServer ran in `palworld_ue4ss_t`;
- no native loader error occurred;
- no nonempty crash file was generated;
- no SELinux AVC was generated;
- no process or test listener survived shutdown.

All five cycles required two process-group `SIGINT` signals. No `SIGTERM`
or `SIGKILL` was required.

The controller status was `130` in every cycle, consistent with
interrupt-driven host-process shutdown.

Final result:

```text
RequestedCycles=5
PassedCycles=5
FailedCycles=0
RESULT=PASS
```

## Explicit teardown behavior

Ordinary host-process termination does not currently invoke the native mod's
`uninstall_mod` export or C++ destructor.

This behavior is recorded independently from the successful repeated native
discovery, dynamic loading, lifecycle callback, Unreal access, and clean
host-process shutdown results.
