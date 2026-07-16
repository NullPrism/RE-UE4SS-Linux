# Repeated Native C++ Mod Loading Acceptance Test

This fixture validates repeatable native Linux C++ mod discovery, dynamic
loading, lifecycle callbacks, Unreal access, and graceful host-process
shutdown across multiple fresh PalServer processes.

The harness runs the native acceptance mod from:

`Mods/NullPrismNativeAcceptance/dlls/main.so`

Each cycle starts a completely fresh PalServer process and verifies:

- `start_mod` executes.
- The native C++ object constructor executes.
- `on_cpp_mods_loaded` executes.
- `on_unreal_init` executes.
- A read-only Unreal UObject lookup succeeds.
- `on_program_start` executes.
- The native shared object is mapped into PalServer.
- UDP ports 8212 and 27016 become active.
- PalServer runs in the scoped `palworld_ue4ss_t` SELinux domain.
- Graceful process-group interrupt handling stops the server.
- Both test ports are released.
- No nonempty crash file or SELinux AVC is generated.

The harness never uses `dlclose`. Each cycle uses a fresh host process.

## Build and installation requirements

The native acceptance module must be built using:

`validation/native/cpp-mod-loading/build.sh`

The harness verifies the installed native module SHA-256 before starting any
cycle.

The native mod must be installed as:

    Mods/
    └── NullPrismNativeAcceptance/
        ├── enabled.txt
        └── dlls/
            └── main.so

## Safety constraints

- Run only against the isolated `palworld-2` acceptance instance.
- Do not run against the production Palworld server.
- Use test ports 8212 and 27016.
- Do not weaken the global SELinux policy.
- Do not unload UE4SS or the native mod using `dlclose`.
- Preserve generated audit archives outside the Git repository.

## Pass criteria

The test passes only when every requested cycle:

- observes all seven native lifecycle markers;
- verifies the native module mapping;
- verifies both test listeners;
- verifies the scoped SELinux domain;
- shuts down without forced termination;
- generates no crash file;
- generates no SELinux AVC;
- leaves no surviving process or test listener.

The harness must emit a final `RESULT=PASS`.

## Teardown observation

Normal PalServer host-process shutdown does not currently invoke the native
mod's `uninstall_mod` export or C++ destructor.

The operating system reclaims the mapped native module when the host process
terminates. Explicit mod-uninstall behavior is distinct from the validated
host-process shutdown path.
