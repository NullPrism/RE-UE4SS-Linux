# RE-UE4SS Linux

[![Native Linux](https://github.com/NullPrism/RE-UE4SS-Linux/actions/workflows/linux-test.yml/badge.svg?branch=main)](https://github.com/NullPrism/RE-UE4SS-Linux/actions/workflows/linux-test.yml)

An unofficial downstream native Linux port and distribution of RE-UE4SS for
headless Unreal Engine games and dedicated servers.

The current binding target is the native Linux Palworld Dedicated Server on
Unreal Engine 5.1.

> This project is not affiliated with or supported by the official UE4SS
> project or Pocketpair.

## Project status

**Experimental, with a validated working core loader path.**

The project has passed live acceptance testing for native loader startup, Lua
mods, reflected Unreal access, hooks, native C++ mods, and repeated fresh-process
startup and shutdown on the validated Palworld target.

This does not establish compatibility with every Unreal Engine game, engine
version, Linux distribution, or existing third-party mod.

Production deployment is not yet recommended until broader game and
third-party-mod compatibility has been established.

Source builds require authorized access to the pinned UEPseudo submodule.
The patternsleuth submodule is public and uses HTTPS, but an anonymous
recursive clone cannot complete without UEPseudo authorization.

## Download and install

The current prerelease is `linux-v0.1.0`, validated for the native Linux
Palworld Dedicated Server version listed below.

1. Download `RE-UE4SS-Linux-0.1.0-x86_64.tar.gz` from the release page.
2. Verify the archive using the accompanying `.sha256` file.
3. Extract the archive.
4. Copy the package contents into `Pal/Binaries/Linux/`.
5. Start the server using the included `run_ue4ss.sh` launcher.

See the complete [installation guide](docs/linux/INSTALLATION.md) before
enabling third-party mods.

## Validated target

| Component | Validated value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Distribution | Fedora Linux |
| Loading method | Process-lifetime `LD_PRELOAD` |
| Imported Linux baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |

See the complete [Linux compatibility matrix](docs/linux/COMPATIBILITY.md).


## Releases

Downstream native Linux releases use the tag format
`linux-vMAJOR.MINOR.PATCH`. This avoids ambiguity with the inherited upstream
UE4SS tags retained in the repository.

The first downstream release,
[`linux-v0.1.0`](https://github.com/NullPrism/RE-UE4SS-Linux/releases/tag/linux-v0.1.0),
is available as a GitHub prerelease. Its release assets were built from an
explicitly pinned source commit and published only after independent package
validation and a 36-cycle fresh-process runtime acceptance matrix.

See the [Linux release policy](docs/linux/RELEASES.md), the
[RE-UE4SS Linux v0.1.0 prerelease notes](docs/linux/RELEASE-NOTES-v0.1.0.md),
and the
[published release](https://github.com/NullPrism/RE-UE4SS-Linux/releases/tag/linux-v0.1.0).

For end-user installation from the published runtime archive, follow the
[`linux-v0.1.0` runtime installation guide](https://github.com/NullPrism/RE-UE4SS-Linux/blob/linux-v0.1.0/packaging/linux/INSTALL.md).

## Validated functionality

The following capabilities have passed live testing on the validated target:

- Native x86-64 Linux UE4SS startup through `LD_PRELOAD`
- Process-scoped launcher behavior for wrapper-based servers
- Palworld Dedicated Server initialization and signature resolution
- Lua mod discovery and execution
- Native lifecycle hook registration
- Native-to-Lua callbacks
- UObject, UClass, UWorld, FName, FString, and FText access
- Reflected primitive numeric property reads
- Controlled reflected property write, readback, and restoration
- Reflected UFunction discovery and invocation
- Primitive UFunction input and return-value marshalling
- Reflected hook context and primitive-parameter handling
- Native Linux C++ `.so` mod discovery and loading
- Native C++ lifecycle callbacks and read-only Unreal access
- Repeated native C++ mod loading across fresh PalServer processes
- Repeated startup and graceful shutdown without surviving processes
- Scoped SELinux operation without enabling global `execheap`

The acceptance fixtures and recorded results are maintained under
[`validation/`](validation/).

## Current scope

This downstream currently targets:

- Native x86-64 Linux
- Headless Unreal Engine servers and games
- Unreal Engine 5.1 as the binding validated engine
- Clang and C++23
- CMake/Ninja and xmake builds
- Lua mods
- Native C++ mods compiled as ELF shared objects

The repository retains inherited cross-platform source and build infrastructure,
but this downstream's compatibility claims and active validation focus on native
Linux.

For supported Windows builds and the established Windows UE4SS ecosystem, use
the official upstream UE4SS project.

## Build requirements

The current Linux build requires:

- x86-64 Linux
- glibc 2.35 or newer
- Clang with C++23 support
- CMake 3.22 or newer and Ninja, or xmake 2.9.3
- Rust 1.73 or newer
- Access to all pinned Git submodules

GCC is not a supported compiler for this downstream.

### Submodule access

The repository contains two pinned submodules:

- `deps/first/Unreal` is UEPseudo and requires authorized GitHub access.
- `deps/first/patternsleuth` is public and uses HTTPS.

Verify UEPseudo access before initializing the complete source tree:

    GIT_TERMINAL_PROMPT=0 \
      git ls-remote \
        git@github.com:Re-UE4SS/UEPseudo.git \
        HEAD

Then synchronize and initialize the pinned revisions:

    git submodule sync --recursive
    git submodule update --init --recursive

An anonymous recursive clone is expected to stop at UEPseudo. This is an
access requirement of that dependency rather than a missing commit or broken
gitlink in this downstream.

Detailed prerequisites, build commands, staging instructions, and diagnostics
are documented in the [native Linux guide](docs/linux.md).

### CMake

    git submodule update --init --recursive

    cmake -S . -B build_linux -G Ninja \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_BUILD_TYPE=Game__Shipping__Linux \
      -DUE4SS_GUI=OFF \
      -DUE4SS_BUILD_TESTS=ON

    cmake --build build_linux --parallel
    ctest --test-dir build_linux --output-on-failure

### xmake

    git submodule update --init --recursive

    xmake f -p linux -a x86_64 -m Game__Shipping__Linux -y
    xmake build -j "$(nproc)" -y UE4SS

The active Native Linux workflow validates both build systems with Clang.

## Runtime layout

UE4SS resolves its settings, mods, logs, and generated output relative to
`libUE4SS.so`.

A staged server generally uses this layout:

    Pal/Binaries/Linux/
    ├── libUE4SS.so
    ├── run_ue4ss.sh
    ├── UE4SS-settings.ini
    ├── UE4SS.log
    ├── UE4SS-crashes/
    └── Mods/

Use the supplied launcher rather than adding `LD_PRELOAD` globally:

    export PALWORLD_SERVER_ROOT=/srv/palworld

    stage="$PALWORLD_SERVER_ROOT/Pal/Binaries/Linux"
    server="$stage/PalServer-Linux-Shipping"
    wrapper="$PALWORLD_SERVER_ROOT/PalServer.sh"

    cd "$PALWORLD_SERVER_ROOT"

    UE4SS_CRASH_LOG_DIR="$stage/UE4SS-crashes" \
      "$stage/run_ue4ss.sh" \
      --host-executable "$server" \
      "$wrapper" \
      -useperfthreads \
      -NoAsyncLoadingThread \
      -UseMultithreadForDS

The launcher identifies the intended host ELF, preserves the user's original
`LD_PRELOAD`, and removes the launcher-added UE4SS preload before the game
starts child processes.

Manual `LD_PRELOAD` remains possible, but it retains normal Linux environment
inheritance and is not the supported process-scoped workflow.

## Mod support

### Lua mods

Lua mods use the standard UE4SS `Mods` structure. The Linux acceptance suite
has validated mod discovery, lifecycle callbacks, reflected properties,
UFunction calls, and hook parameter handling.

### Native C++ mods

A native Linux C++ mod is loaded from:

    Mods/<ModName>/dlls/main.so

The shared object must export:

    start_mod
    uninstall_mod

Native C++ mods are ABI-coupled to UE4SS. They must be built against the same
UE4SS source revision, headers, build configuration, compiler/runtime strategy,
and compatible C++ ABI as the loader that will load them.

The reference acceptance fixture is located at
[`validation/native/cpp-mod-loading/`](validation/native/cpp-mod-loading/).

Normal PalServer host-process shutdown did not call the native mod's
`uninstall_mod` export or C++ destructor during validation. The operating system
reclaimed the module when the host process terminated.

## Limitations

- Compatibility evidence applies only to explicitly tested combinations.
- x86-64 is supported; ARM64 is not currently supported.
- The ImGui GUI and live GUI tools are compiled out.
- Keyboard and mouse hooks are unavailable in the headless target.
- UVTD and PDB-based tooling are unavailable.
- Native loading uses `LD_PRELOAD`; there is no ptrace/attach injector.
- Linux crash handling produces signal backtraces rather than Windows minidumps.
- UE4SS and native mods must not be unloaded with `dlclose`.
- Stop the host process to unload the loader.
- Existing third-party Linux mod compatibility remains unvalidated.
- Pinned dependency revisions are not yet guaranteed to be reachable through
  stable public submodule remotes.

## Documentation

- [`linux-v0.1.0` runtime installation guide](https://github.com/NullPrism/RE-UE4SS-Linux/blob/linux-v0.1.0/packaging/linux/INSTALL.md)
- [Native Linux build, staging, launch, and diagnostics](docs/linux.md)
- [Compatibility matrix](docs/linux/COMPATIBILITY.md)
- [Source provenance](docs/linux/PROVENANCE.md)
- [Validation fixtures and recorded results](validation/)
- [Single-process native C++ loading result](validation/native/cpp-mod-loading/RESULT-PALWORLD-24181105.md)
- [Repeated native C++ loading result](validation/runtime/repeated-native-cpp-mod-loading/RESULT-PALWORLD-24181105.md)
- [Repeated loader startup and shutdown result](validation/runtime/repeated-startup-shutdown/RESULT-PALWORLD-24181105.md)

## Source provenance

This repository derives from:

- `UE4SS-RE/RE-UE4SS`, the official upstream project
- `tc-imba/RE-UE4SS`, branch `linux-port`

The imported Linux baseline is preserved as:

    Commit: 407d14cf3c485a150cd157fd581643c901dd9b0e
    Tag:    tc-imba-linux-port-baseline-407d14c

The complete provenance record is available in
[`docs/linux/PROVENANCE.md`](docs/linux/PROVENANCE.md).

Portable fixes may be proposed upstream separately as small, independently
reviewable changes.

## Contributing

Changes should be narrowly scoped, reviewable, and accompanied by appropriate
build or runtime validation.

Linux runtime changes should document:

- the tested game and engine version;
- the loader and executable identities;
- the exact acceptance criteria;
- any crash or SELinux audit result;
- whether the change affects Lua, native C++, or process lifecycle behavior.

Do not commit proprietary game binaries, generated runtime artifacts, crash
archives, or private dependency credentials.

## License

This downstream retains the repository's existing license and upstream
copyright notices.

See [`LICENSE`](LICENSE).
