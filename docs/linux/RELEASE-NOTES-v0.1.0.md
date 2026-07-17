# RE-UE4SS Linux v0.1.0

This is the first native Linux downstream prerelease of RE-UE4SS.

## Validated target

- Palworld Dedicated Server `1.0.1.100619`
- Steam build ID `24181105`
- Unreal Engine `5.1.1`
- Native x86-64 Linux server
- Fedora Linux 43 validation host
- glibc-based headless runtime
- PalServer SHA-256 `788649fa1592160faa7bcf07ccd16d474ebeaae954717bc32284b5a43028d8e7`
- PalServer ELF build ID `7f7e167407984ec3`
- Final acceptance matrix: 36 fresh-process cycles
  (1 smoke, 5 core-only, 20 Lua-only, 5 native-only,
  and 5 Lua-plus-native)
- Runtime acceptance source: the commit referenced by the
  `linux-v0.1.0` tag and recorded in `RELEASE-MANIFEST.txt`
- Runtime-accepted packaged loader identity: recorded in
  `RELEASE-MANIFEST.txt` and the package's `BUILD-METADATA.txt`

The release source commit is the commit referenced by the `linux-v0.1.0` tag
and recorded inside the package's `BUILD-METADATA.txt`.

## Highlights

- Native x86-64 ELF `libUE4SS.so`
- Process-scoped `LD_PRELOAD` launcher
- Lua mod discovery and execution
- Native Linux C++ `.so` mod loading
- UObject, UClass, UWorld, FName, FString, and FText access
- Reflected property reads and controlled writes
- Reflected UFunction invocation and parameter handling
- Native and Lua hook callbacks
- Repeated fresh-process startup and graceful shutdown
- Scoped SELinux operation without enabling global `execheap`
- Reproducible runtime and separate debug-symbol archives
- Bundled optional mods disabled by default

## Downloads

- `RE-UE4SS-Linux-0.1.0-x86_64.tar.gz`
- `RE-UE4SS-Linux-0.1.0-x86_64-debug.tar.gz`
- `RELEASE-MANIFEST.txt`, containing archive SHA-256 values and build identity

The runtime archive contains the loader, launcher, settings, bundled mod files,
installation documentation, provenance metadata, and internal checksums.

## Compatibility scope

This prerelease does not claim compatibility with every Unreal Engine game,
engine version, Linux distribution, or existing third-party UE4SS mod.

Compatibility applies only to combinations explicitly recorded in the Linux
compatibility matrix. Existing third-party Linux mod compatibility remains
under evaluation.

Do not unload UE4SS using `dlclose`. Stop the host process to unload the loader.

## Native Linux prerelease limitations

- The per-mod Lua asynchronous worker is disabled on native Linux to avoid an intermittent shutdown-time `std::system_error`/SIGABRT. Standard Lua mod loading and tested Unreal hooks remain operational. Lua features that require the asynchronous worker may be unavailable.
- One non-reproduced shutdown-time SIGSEGV occurred during extended diagnostic testing. Twenty subsequent cycles with core capture enabled completed cleanly. This is recorded as a rare shutdown observation and is not considered a blocker for the v0.1.0 prerelease.
- Marker-free raw `LD_PRELOAD` and explicit `dlopen` auto-start are fail-closed by default. Set `UE4SS_ALLOW_LEGACY_START=1` only for deliberate legacy compatibility; the supported path is `run_ue4ss.sh`.
