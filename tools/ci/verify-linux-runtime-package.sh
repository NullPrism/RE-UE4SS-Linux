#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

trap 'status=$?; printf "ERROR: command failed at line %s (status %s): %s\n" "$LINENO" "$status" "$BASH_COMMAND" >&2; exit "$status"' ERR

usage()
{
    echo "usage: $0 <runtime-archive.tar.gz> <debug-archive.tar.gz>" >&2
}

if (( $# != 2 )); then
    usage
    exit 2
fi

runtime_archive="$(
    readlink -f -- "$1"
)"

debug_archive="$(
    readlink -f -- "$2"
)"

for archive in "$runtime_archive" "$debug_archive"; do
    if [[ ! -f "$archive" ]]; then
        echo "ERROR: archive was not found: $archive" >&2
        exit 1
    fi

    if [[ -f "${archive}.sha256" ]]; then
        (
            cd "$(dirname "$archive")"

            sha256sum \
                -c \
                "$(basename "${archive}.sha256")"
        )
    fi
done

runtime_name="$(
    basename "$runtime_archive" .tar.gz
)"

debug_name="$(
    basename "$debug_archive" .tar.gz
)"

scratch_root="$(
    mktemp -d
)"

cleanup()
{
    rm -rf -- "$scratch_root"
}

trap cleanup EXIT

validate_archive_paths()
{
    local archive="$1"
    local expected_root="$2"
    local listing="$scratch_root/$(basename "$archive").list"

    tar \
        -tzf \
        "$archive" \
        > "$listing"

    if [[ ! -s "$listing" ]]; then
        echo "ERROR: archive is empty: $archive" >&2
        exit 1
    fi

    if awk '
        /^\// {
            invalid=1
        }

        /(^|\/)\.\.(\/|$)/ {
            invalid=1
        }

        END {
            exit(invalid ? 0 : 1)
        }
    ' "$listing"; then

        echo "ERROR: archive contains an unsafe path: $archive" >&2
        exit 1
    fi

    if grep -Ev \
        "^${expected_root}(/|$)" \
        "$listing" \
        >/dev/null; then

        echo "ERROR: archive contains an unexpected top-level path:" >&2
        grep -Ev \
            "^${expected_root}(/|$)" \
            "$listing" >&2
        exit 1
    fi
}

validate_archive_paths \
    "$runtime_archive" \
    "$runtime_name"

validate_archive_paths \
    "$debug_archive" \
    "$debug_name"

tar \
    -xzf \
    "$runtime_archive" \
    -C "$scratch_root"

tar \
    -xzf \
    "$debug_archive" \
    -C "$scratch_root"

runtime_root="$scratch_root/$runtime_name"
debug_root="$scratch_root/$debug_name"

if [[ ! -d "$runtime_root" ]] ||
   [[ ! -d "$debug_root" ]]; then

    echo "ERROR: expected archive roots were not extracted." >&2
    exit 1
fi

if find \
    "$runtime_root" \
    "$debug_root" \
    -type l \
    -print \
    -quit |
    grep -q .; then

    echo "ERROR: package contains a symbolic link." >&2
    exit 1
fi

expected_runtime_entries="$scratch_root/expected-runtime.txt"
actual_runtime_entries="$scratch_root/actual-runtime.txt"

cat > "$expected_runtime_entries" <<'EOF'
BUILD-METADATA.txt
INSTALL.md
LICENSE
Mods
PROVENANCE.md
SHA256SUMS
UE4SS-crashes
UE4SS-settings.ini
libUE4SS.so
run_ue4ss.sh
EOF

find "$runtime_root" \
    -mindepth 1 \
    -maxdepth 1 \
    -printf '%f\n' |
sort \
    > "$actual_runtime_entries"

if ! diff \
    -u \
    "$expected_runtime_entries" \
    "$actual_runtime_entries"; then

    echo "ERROR: runtime package top-level contents differ." >&2
    exit 1
fi

expected_debug_entries="$scratch_root/expected-debug.txt"
actual_debug_entries="$scratch_root/actual-debug.txt"

cat > "$expected_debug_entries" <<'EOF'
BUILD-METADATA.txt
LICENSE
SHA256SUMS
libUE4SS.so.debug
EOF

find "$debug_root" \
    -mindepth 1 \
    -maxdepth 1 \
    -printf '%f\n' |
sort \
    > "$actual_debug_entries"

if ! diff \
    -u \
    "$expected_debug_entries" \
    "$actual_debug_entries"; then

    echo "ERROR: debug package top-level contents differ." >&2
    exit 1
fi

require_mode()
{
    local expected="$1"
    local path="$2"
    local actual

    actual="$(
        stat \
            --printf='%a' \
            "$path"
    )"

    if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: unexpected mode for $path" >&2
        echo "Expected: $expected" >&2
        echo "Actual:   $actual" >&2
        exit 1
    fi
}

require_mode 755 "$runtime_root"
require_mode 755 "$runtime_root/libUE4SS.so"
require_mode 755 "$runtime_root/run_ue4ss.sh"
require_mode 755 "$runtime_root/Mods"
require_mode 755 "$runtime_root/UE4SS-crashes"
require_mode 644 "$runtime_root/UE4SS-settings.ini"
require_mode 644 "$runtime_root/BUILD-METADATA.txt"
require_mode 644 "$runtime_root/INSTALL.md"
require_mode 644 "$runtime_root/LICENSE"
require_mode 644 "$runtime_root/PROVENANCE.md"
require_mode 644 "$runtime_root/SHA256SUMS"
require_mode 644 "$debug_root/libUE4SS.so.debug"

if find \
    "$runtime_root/UE4SS-crashes" \
    -mindepth 1 \
    -print \
    -quit |
    grep -q .; then

    echo "ERROR: UE4SS-crashes is not empty." >&2
    exit 1
fi

for required_mod_file in \
    "$runtime_root/Mods/mods.json" \
    "$runtime_root/Mods/mods.txt" \
    "$runtime_root/Mods/shared/Types.lua"
do
    if [[ ! -f "$required_mod_file" ]]; then
        echo "ERROR: required bundled mod file is missing:" >&2
        echo "$required_mod_file" >&2
        exit 1
    fi
done

runtime_description="$(
    file \
        -b \
        "$runtime_root/libUE4SS.so"
)"

if [[ "$runtime_description" != *"ELF 64-bit LSB shared object"* ]] ||
   [[ "$runtime_description" != *"x86-64"* ]]; then

    echo "ERROR: packaged runtime loader is not x86-64 ELF." >&2
    exit 1
fi

runtime_dynamic_section="$(
    readelf -W -d "$runtime_root/libUE4SS.so"
)"

runtime_sections="$(
    readelf -W -S "$runtime_root/libUE4SS.so"
)"

debug_sections="$(
    readelf -W -S "$debug_root/libUE4SS.so.debug"
)"

if [[ "$runtime_dynamic_section" != *"(SONAME)"*"[libUE4SS.so]"* ]]; then
    echo "ERROR: packaged loader SONAME is invalid." >&2
    exit 1
fi

if [[ "$runtime_sections" == *".debug_info"* ]]; then
    echo "ERROR: runtime loader contains .debug_info." >&2
    exit 1
fi

if [[ "$runtime_sections" != *".gnu_debuglink"* ]]; then
    echo "ERROR: runtime loader lacks .gnu_debuglink." >&2
    exit 1
fi

if [[ "$debug_sections" != *".debug_info"* ]] &&
   [[ "$debug_sections" != *".debug_line"* ]]; then

    echo "ERROR: debug package lacks usable debug sections." >&2
    exit 1
fi

relocation_status=0

relocation_output="$(
    ldd \
        -r \
        "$runtime_root/libUE4SS.so" \
        2>&1
)" || relocation_status=$?

printf '%s\n' "$relocation_output"

if (( relocation_status != 0 )); then
    echo "ERROR: ldd failed for the runtime loader." >&2
    exit 1
fi

if grep -Eqi \
    'undefined symbol|not found' \
    <<< "$relocation_output"; then

    echo "ERROR: runtime loader relocation validation failed." >&2
    exit 1
fi

(
    cd "$runtime_root"
    sha256sum -c SHA256SUMS
)

(
    cd "$debug_root"
    sha256sum -c SHA256SUMS
)

if ! cmp \
    -s \
    "$runtime_root/BUILD-METADATA.txt" \
    "$debug_root/BUILD-METADATA.txt"; then

    echo "ERROR: runtime and debug metadata differ." >&2
    exit 1
fi

for metadata_key in \
    PackageName \
    PackageVersion \
    Architecture \
    BuildConfiguration \
    PackageSourceCommit \
    LoaderSourceCommit \
    LoaderBuildID \
    LoaderInputSHA256 \
    LoaderPackagedSHA256 \
    LoaderDebugSHA256 \
    UEPseudoCommit \
    PatternSleuthCommit
do
    if ! grep -Eq \
        "^${metadata_key}=.+" \
        "$runtime_root/BUILD-METADATA.txt"; then

        echo "ERROR: metadata key is missing: $metadata_key" >&2
        exit 1
    fi
done

echo
echo "RuntimePackage=$runtime_name"
echo "DebugPackage=$debug_name"
echo "RESULT=PASS"
