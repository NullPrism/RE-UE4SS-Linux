# Native C++ Mod Loading Acceptance Test

This fixture validates native Linux C++ mod discovery, dynamic loading,
lifecycle callbacks, Unreal access, and clean host-process shutdown through
UE4SS.

The fixture builds:

`Mods/NullPrismNativeAcceptance/dlls/main.so`

The shared object exports:

- `start_mod`
- `uninstall_mod`

The mod derives from `RC::CppUserModBase` and emits markers from:

- `start_mod`
- its constructor
- `on_cpp_mods_loaded`
- `on_unreal_init`
- `on_program_start`
- `uninstall_mod`
- its destructor

During `on_unreal_init`, the mod performs a read-only lookup for:

`/Script/CoreUObject.Object`

## Build constraints

The test mod must be built against the same UE4SS source, headers, build
configuration, C++ runtime strategy, and loader ABI as the tested
`libUE4SS.so`.

The build script verifies the expected loader SHA-256 before compilation.

Generated files under `build/` are not committed.

## Installation layout

    Mods/
    └── NullPrismNativeAcceptance/
        ├── enabled.txt
        └── dlls/
            └── main.so

## Pass criteria

The test passes only when:

- `main.so` is a valid x86-64 ELF shared object.
- `start_mod` and `uninstall_mod` are exported.
- All relocations resolve against the tested `libUE4SS.so`.
- UE4SS discovers and maps the shared object.
- `start_mod` executes.
- The C++ constructor executes.
- `on_cpp_mods_loaded` executes.
- `on_unreal_init` executes.
- The read-only Unreal object lookup succeeds.
- `on_program_start` executes.
- PalServer opens both isolated test ports.
- PalServer runs in the scoped `palworld_ue4ss_t` SELinux domain.
- No loader error, nonempty crash record, or SELinux AVC occurs.
- PalServer exits cleanly and releases both test ports.

## Teardown observation

Ordinary PalServer host-process shutdown did not call `uninstall_mod` or the
C++ destructor during the validated run.

This does not invalidate native loading or execution. The explicit uninstall
exports are required and resolved successfully, but ordinary host termination
does not traverse UE4SS's explicit mod-uninstall path.
