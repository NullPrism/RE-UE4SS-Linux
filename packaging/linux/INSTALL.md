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

## SELinux preflight and game updates

Do not enable the global `execheap` boolean solely for UE4SS. Use a narrowly
scoped SELinux domain that permits executable trampoline memory only for the
intended UE4SS-enabled host process.

The launcher supports these SELinux preflight modes:

```bash
UE4SS_SELINUX_PREFLIGHT=off
UE4SS_SELINUX_PREFLIGHT=warn
UE4SS_SELINUX_PREFLIGHT=strict
```

The default is `warn`. A scoped deployment should also identify the expected
entrypoint type:

```bash
UE4SS_SELINUX_PREFLIGHT=strict \
UE4SS_EXPECTED_SELINUX_TYPE=palworld_ue4ss_exec_t \
  "$stage/run_ue4ss.sh" \
  --host-executable "$server" \
  "$wrapper"
```

When SELinux is Enforcing, `strict` mode exits with status 8 if the host
executable does not have the expected type. This prevents a later executable
trampoline fault when the process fails to transition into its scoped domain.

Game updates and validation operations can replace the host executable with a
new inode. The replacement may receive the directory's default SELinux type
instead of the persistent custom entrypoint type.

Define a persistent file-context mapping once:

```bash
semanage fcontext -a \
  -t palworld_ue4ss_exec_t \
  '/srv/palworld/Pal/Binaries/Linux/PalServer-Linux-Shipping'
```

After every game update or validation, restore the configured context before
starting UE4SS:

```bash
restorecon -Fv \
  /srv/palworld/Pal/Binaries/Linux/PalServer-Linux-Shipping

matchpathcon -V \
  /srv/palworld/Pal/Binaries/Linux/PalServer-Linux-Shipping
```

Use `semanage fcontext -m` instead of `-a` when changing an existing mapping.
Do not rely on `chcon`; it changes the current label without defining the
persistent file-context rule.

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
