# RE-UE4SS Linux Runtime Installation

This package contains the experimental native Linux UE4SS runtime.

Compatibility is limited to explicitly validated game, engine, architecture,
distribution, and loader combinations. Review `PROVENANCE.md` and the project
compatibility matrix before deploying it to a production server.

## Package contents

- `libUE4SS.so`: native Linux UE4SS loader
- `run_ue4ss.sh`: process-scoped LD_PRELOAD launcher
- `UE4SS-settings.ini`: default runtime configuration
- `Mods/`: bundled UE4SS Lua mods and mod configuration
- `UE4SS-crashes/`: default Linux crash-log directory
- `BUILD-METADATA.txt`: source and artifact identities
- `SHA256SUMS`: checksums for files inside this package

Bundled mods are disabled by default. Enable only the individual mods required
for the target server after reviewing their behavior and compatibility.

Debug symbols are distributed separately.

## Verify the package

From inside the extracted package directory:

    sha256sum -c SHA256SUMS

Do not install the package if any checksum fails.

## Back up an existing installation

Before copying files into a game directory, back up any existing:

- `libUE4SS.so`
- `run_ue4ss.sh`
- `UE4SS-settings.ini`
- `Mods/`
- `UE4SS.log`
- `UE4SS-crashes/`

Do not overwrite an existing mod configuration without reviewing it.

## Palworld Dedicated Server layout

For Palworld, stage the package contents beside the native server executable:

    Pal/Binaries/Linux/
    ├── libUE4SS.so
    ├── run_ue4ss.sh
    ├── UE4SS-settings.ini
    ├── Mods/
    └── UE4SS-crashes/

Example installation:

    package_root=/path/to/RE-UE4SS-Linux-package
    stage=/srv/palworld/Pal/Binaries/Linux

    install -m 0755 \
      "$package_root/libUE4SS.so" \
      "$stage/libUE4SS.so"

    install -m 0755 \
      "$package_root/run_ue4ss.sh" \
      "$stage/run_ue4ss.sh"

    install -m 0644 \
      "$package_root/UE4SS-settings.ini" \
      "$stage/UE4SS-settings.ini"

    cp -a \
      "$package_root/Mods/." \
      "$stage/Mods/"

    install -d -m 0755 \
      "$stage/UE4SS-crashes"

## Launch through a wrapper script

When the game normally starts through a shell wrapper, identify the real ELF
host explicitly:

    PALWORLD_SERVER_ROOT=/srv/palworld
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

## Launch the ELF directly

When no wrapper is required:

    stage=/srv/palworld/Pal/Binaries/Linux
    server="$stage/PalServer-Linux-Shipping"

    UE4SS_CRASH_LOG_DIR="$stage/UE4SS-crashes" \
      "$stage/run_ue4ss.sh" \
      "$server" \
      Pal \
      -useperfthreads \
      -NoAsyncLoadingThread \
      -UseMultithreadForDS

## Diagnostics

Enable the Linux startup diagnostic report with:

    UE4SS_DIAGNOSE=1

Review:

- `UE4SS.log`
- files under `UE4SS-crashes/`
- the game-server console output
- the executable SHA-256
- the game and Steam build versions

## Unloading

Do not unload `libUE4SS.so` or native C++ mods with `dlclose`.

Stop the host game process to unload the loader and its native mods.

## SELinux

Do not enable global `execheap` solely for UE4SS.

The validated Palworld environment used a narrowly scoped SELinux domain and
policy for the isolated UE4SS-enabled server process. Deployments using SELinux
should apply an equally restricted local policy.
