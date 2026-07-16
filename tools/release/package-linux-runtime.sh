#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

trap 'status=$?; printf "ERROR: command failed at line %s (status %s): %s\n" "$LINENO" "$status" "$BASH_COMMAND" >&2; exit "$status"' ERR

usage()
{
    cat >&2 <<'EOF'
Usage:
  package-linux-runtime.sh \
    --loader <path-to-libUE4SS.so> \
    --version <package-version> \
    --output-dir <directory> \
    [--source-commit <git-commit>] \
    [--loader-source-commit <git-commit>]
EOF
}

find_tool()
{
    local candidate

    for candidate in "$@"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done

    echo "ERROR: required tool was not found: $*" >&2
    return 1
}

loader=""
version=""
output_dir=""
source_commit=""
loader_source_commit=""

while (( $# > 0 )); do
    case "$1" in
        --loader)
            loader="${2:-}"
            shift 2
            ;;
        --version)
            version="${2:-}"
            shift 2
            ;;
        --output-dir)
            output_dir="${2:-}"
            shift 2
            ;;
        --source-commit)
            source_commit="${2:-}"
            shift 2
            ;;
        --loader-source-commit)
            loader_source_commit="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if [[ -z "$loader" ]] ||
   [[ -z "$version" ]] ||
   [[ -z "$output_dir" ]]; then

    usage
    exit 2
fi

if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
    echo "ERROR: invalid package version: $version" >&2
    exit 2
fi

repo_root="$(
    git rev-parse --show-toplevel
)"

source_commit="${source_commit:-$(git rev-parse HEAD)}"
loader_source_commit="${loader_source_commit:-$source_commit}"

for commit in "$source_commit" "$loader_source_commit"; do
    if ! git -C "$repo_root" \
        cat-file \
        -e "${commit}^{commit}" 2>/dev/null; then

        echo "ERROR: commit is not available locally: $commit" >&2
        exit 1
    fi
done

source_commit="$(
    git -C "$repo_root" \
        rev-parse "$source_commit"
)"

loader_source_commit="$(
    git -C "$repo_root" \
        rev-parse "$loader_source_commit"
)"

source_date_epoch="$(
    git -C "$repo_root" \
        show \
        -s \
        --format=%ct \
        "$source_commit"
)"

loader="$(
    readlink -f -- "$loader"
)"

if [[ ! -f "$loader" ]]; then
    echo "ERROR: loader was not found: $loader" >&2
    exit 1
fi

mkdir -p "$output_dir"

output_dir="$(
    cd "$output_dir"
    pwd -P
)"

required_files=(
    "$repo_root/tools/linux/run_ue4ss.sh"
    "$repo_root/tools/ci/verify-disabled-mod-defaults.py"
    "$repo_root/assets/UE4SS-settings.ini"
    "$repo_root/packaging/linux/INSTALL.md"
    "$repo_root/docs/linux/PROVENANCE.md"
    "$repo_root/LICENSE"
)

for required_file in "${required_files[@]}"; do
    if [[ ! -f "$required_file" ]]; then
        echo "ERROR: required packaging input is missing:" >&2
        echo "$required_file" >&2
        exit 1
    fi
done

if [[ ! -d "$repo_root/assets/Mods" ]]; then
    echo "ERROR: bundled Mods directory is missing." >&2
    exit 1
fi

"$repo_root/tools/ci/verify-disabled-mod-defaults.py" \
    "$repo_root/assets/Mods/mods.json" \
    "$repo_root/assets/Mods/mods.txt"

objcopy="$(
    find_tool \
        llvm-objcopy-20 \
        llvm-objcopy \
        objcopy
)"

strip_tool="$(
    find_tool \
        llvm-strip-20 \
        llvm-strip \
        strip
)"

readelf_tool="$(
    find_tool readelf llvm-readelf-20 llvm-readelf
)"

file_tool="$(
    find_tool file
)"

loader_description="$(
    "$file_tool" -b "$loader"
)"

if [[ "$loader_description" != *"ELF 64-bit LSB shared object"* ]] ||
   [[ "$loader_description" != *"x86-64"* ]]; then

    echo "ERROR: loader is not an x86-64 ELF shared object:" >&2
    echo "$loader_description" >&2
    exit 1
fi

loader_dynamic_section="$(
    "$readelf_tool" -W -d "$loader"
)"

if [[ "$loader_dynamic_section" != *"(SONAME)"*"[libUE4SS.so]"* ]]; then
    echo "ERROR: loader SONAME is not libUE4SS.so." >&2
    exit 1
fi

relocation_status=0

relocation_output="$(
    ldd -r "$loader" 2>&1
)" || relocation_status=$?

if (( relocation_status != 0 )); then
    echo "ERROR: ldd failed for the input loader." >&2
    printf '%s\n' "$relocation_output" >&2
    exit 1
fi

if grep -Eqi \
    'undefined symbol|not found' \
    <<< "$relocation_output"; then

    echo "ERROR: loader relocation validation failed." >&2
    printf '%s\n' "$relocation_output" >&2
    exit 1
fi

loader_notes="$(
    "$readelf_tool" -n "$loader" 2>/dev/null
)"

loader_build_id="$(
    awk '
        /Build ID:/ && build_id == "" {
            build_id=$3
        }

        END {
            if (build_id != "") {
                print build_id
            }
        }
    ' <<< "$loader_notes"
)"

if [[ -z "$loader_build_id" ]]; then
    echo "ERROR: loader does not contain a GNU Build ID." >&2
    exit 1
fi

input_loader_sha256="$(
    sha256sum "$loader" |
    awk '{print $1}'
)"

uepseudo_commit="$(
    git -C "$repo_root" \
        ls-tree \
        "$loader_source_commit" \
        deps/first/Unreal |
    awk '{print $3}'
)"

patternsleuth_commit="$(
    git -C "$repo_root" \
        ls-tree \
        "$loader_source_commit" \
        deps/first/patternsleuth |
    awk '{print $3}'
)"

for dependency in "$uepseudo_commit" "$patternsleuth_commit"; do
    if [[ ! "$dependency" =~ ^[0-9a-f]{40}$ ]]; then
        echo "ERROR: invalid dependency gitlink in loader source commit." >&2
        exit 1
    fi
done

runtime_name="RE-UE4SS-Linux-${version}-x86_64"
debug_name="RE-UE4SS-Linux-${version}-x86_64-debug"

runtime_archive="$output_dir/${runtime_name}.tar.gz"
debug_archive="$output_dir/${debug_name}.tar.gz"

rm -f \
    "$runtime_archive" \
    "${runtime_archive}.sha256" \
    "$debug_archive" \
    "${debug_archive}.sha256"

work_root="$(
    mktemp -d
)"

cleanup()
{
    rm -rf -- "$work_root"
}

trap cleanup EXIT

runtime_root="$work_root/$runtime_name"
debug_root="$work_root/$debug_name"

install -d -m 0755 \
    "$runtime_root" \
    "$runtime_root/Mods" \
    "$runtime_root/UE4SS-crashes" \
    "$debug_root"

runtime_loader="$runtime_root/libUE4SS.so"
debug_file="$debug_root/libUE4SS.so.debug"

install -m 0755 \
    "$loader" \
    "$runtime_loader"

"$objcopy" \
    --only-keep-debug \
    "$loader" \
    "$debug_file"

"$strip_tool" \
    --strip-unneeded \
    "$runtime_loader"

"$objcopy" \
    --add-gnu-debuglink="$debug_file" \
    "$runtime_loader"

install -m 0755 \
    "$repo_root/tools/linux/run_ue4ss.sh" \
    "$runtime_root/run_ue4ss.sh"

install -m 0644 \
    "$repo_root/assets/UE4SS-settings.ini" \
    "$runtime_root/UE4SS-settings.ini"

install -m 0644 \
    "$repo_root/packaging/linux/INSTALL.md" \
    "$runtime_root/INSTALL.md"

install -m 0644 \
    "$repo_root/LICENSE" \
    "$runtime_root/LICENSE"

install -m 0644 \
    "$repo_root/docs/linux/PROVENANCE.md" \
    "$runtime_root/PROVENANCE.md"

install -m 0644 \
    "$repo_root/LICENSE" \
    "$debug_root/LICENSE"

cp -a \
    "$repo_root/assets/Mods/." \
    "$runtime_root/Mods/"

"$repo_root/tools/ci/verify-disabled-mod-defaults.py" \
    "$runtime_root/Mods/mods.json" \
    "$runtime_root/Mods/mods.txt"

find "$runtime_root" \
    -type d \
    -exec chmod 0755 {} +

find "$runtime_root" \
    -type f \
    -exec chmod 0644 {} +

chmod 0755 \
    "$runtime_loader" \
    "$runtime_root/run_ue4ss.sh"

chmod 0644 \
    "$debug_file" \
    "$debug_root/LICENSE"

runtime_sections="$(
    "$readelf_tool" -W -S "$runtime_loader"
)"

debug_sections="$(
    "$readelf_tool" -W -S "$debug_file"
)"

if [[ "$runtime_sections" == *".debug_info"* ]]; then
    echo "ERROR: packaged runtime loader still contains .debug_info." >&2
    exit 1
fi

if [[ "$runtime_sections" != *".gnu_debuglink"* ]]; then
    echo "ERROR: packaged runtime loader lacks .gnu_debuglink." >&2
    exit 1
fi

if [[ "$debug_sections" != *".debug_info"* ]] &&
   [[ "$debug_sections" != *".debug_line"* ]]; then

    echo "ERROR: debug-symbol file does not contain debug sections." >&2
    exit 1
fi

packaged_loader_description="$(
    "$file_tool" -b "$runtime_loader"
)"

if [[ "$packaged_loader_description" != *"ELF 64-bit LSB shared object"* ]] ||
   [[ "$packaged_loader_description" != *"x86-64"* ]]; then

    echo "ERROR: packaged loader is not a valid x86-64 ELF shared object." >&2
    exit 1
fi

packaged_dynamic_section="$(
    "$readelf_tool" -W -d "$runtime_loader"
)"

if [[ "$packaged_dynamic_section" != *"(SONAME)"*"[libUE4SS.so]"* ]]; then
    echo "ERROR: packaged loader SONAME changed unexpectedly." >&2
    exit 1
fi

packaged_relocation_status=0

packaged_relocation_output="$(
    ldd -r "$runtime_loader" 2>&1
)" || packaged_relocation_status=$?

if (( packaged_relocation_status != 0 )); then
    echo "ERROR: ldd failed for the packaged loader." >&2
    printf '%s\n' "$packaged_relocation_output" >&2
    exit 1
fi

if grep -Eqi \
    'undefined symbol|not found' \
    <<< "$packaged_relocation_output"; then

    echo "ERROR: packaged loader relocation validation failed." >&2
    printf '%s\n' "$packaged_relocation_output" >&2
    exit 1
fi

packaged_loader_sha256="$(
    sha256sum "$runtime_loader" |
    awk '{print $1}'
)"

debug_sha256="$(
    sha256sum "$debug_file" |
    awk '{print $1}'
)"

metadata_file="$work_root/BUILD-METADATA.txt"

cat > "$metadata_file" <<EOF
PackageName=RE-UE4SS-Linux
PackageVersion=$version
Architecture=x86_64
BuildConfiguration=Game__Shipping__Linux
PackageSourceCommit=$source_commit
LoaderSourceCommit=$loader_source_commit
SourceDateEpoch=$source_date_epoch
LoaderBuildID=$loader_build_id
LoaderInputSHA256=$input_loader_sha256
LoaderPackagedSHA256=$packaged_loader_sha256
LoaderDebugSHA256=$debug_sha256
UEPseudoCommit=$uepseudo_commit
PatternSleuthCommit=$patternsleuth_commit
PackagingScript=tools/release/package-linux-runtime.sh
EOF

install -m 0644 \
    "$metadata_file" \
    "$runtime_root/BUILD-METADATA.txt"

install -m 0644 \
    "$metadata_file" \
    "$debug_root/BUILD-METADATA.txt"

(
    cd "$runtime_root"

    find . \
        -type f \
        ! -name SHA256SUMS \
        -print0 |
    sort -z |
    xargs -0 sha256sum \
        > SHA256SUMS
)

(
    cd "$debug_root"

    find . \
        -type f \
        ! -name SHA256SUMS \
        -print0 |
    sort -z |
    xargs -0 sha256sum \
        > SHA256SUMS
)

chmod 0644 \
    "$runtime_root/SHA256SUMS" \
    "$debug_root/SHA256SUMS"

create_archive()
{
    local root_name="$1"
    local archive="$2"

    (
        cd "$work_root"

        tar \
            --sort=name \
            --mtime="@${source_date_epoch}" \
            --owner=0 \
            --group=0 \
            --numeric-owner \
            --format=gnu \
            -cf - \
            "$root_name" |
        gzip \
            -n \
            -9 \
            > "$archive"
    )
}

create_archive \
    "$runtime_name" \
    "$runtime_archive"

create_archive \
    "$debug_name" \
    "$debug_archive"

(
    cd "$output_dir"

    sha256sum \
        "$(basename "$runtime_archive")" \
        > "$(basename "$runtime_archive").sha256"

    sha256sum \
        "$(basename "$debug_archive")" \
        > "$(basename "$debug_archive").sha256"
)

echo "Runtime archive:"
echo "$runtime_archive"
cat "${runtime_archive}.sha256"

echo
echo "Debug archive:"
echo "$debug_archive"
cat "${debug_archive}.sha256"
