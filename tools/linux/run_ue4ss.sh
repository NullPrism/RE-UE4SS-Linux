#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ue4ss_library="${script_dir}/libUE4SS.so"

usage() {
    echo "usage: $0 [--host-executable <ELF executable>] <command> [arguments ...]" >&2
}

canonical_path() {
    readlink -f -- "$1"
}

is_elf_file() {
    [[ "$(LC_ALL=C od -An -t x1 -N4 -- "$1" | tr -d '[:space:]')" == "7f454c46" ]]
}

selinux_file_type() {
    local context
    local selinux_user
    local selinux_role
    local file_type
    local selinux_level

    context="$(stat -Lc '%C' -- "$1" 2>/dev/null || true)"

    if [[ -z "${context}" || "${context}" == "?" ]]; then
        return 1
    fi

    IFS=: read -r \
        selinux_user \
        selinux_role \
        file_type \
        selinux_level \
        <<<"${context}"

    if [[ -z "${file_type}" ]]; then
        return 1
    fi

    printf '%s\n' "${file_type}"
}

selinux_preflight_problem() {
    local mode="$1"
    shift

    echo "UE4SS launcher: SELinux preflight: $*" >&2
    echo "UE4SS launcher: a game update may have replaced the labeled host executable; restore its persistent file context before launch." >&2

    if [[ "${mode}" == "strict" ]]; then
        exit 8
    fi
}

selinux_preflight() {
    local mode="${UE4SS_SELINUX_PREFLIGHT:-warn}"
    local file_type
    local expected_type="${UE4SS_EXPECTED_SELINUX_TYPE:-}"

    case "${mode}" in
        off|warn|strict)
            ;;
        *)
            echo "UE4SS launcher: invalid UE4SS_SELINUX_PREFLIGHT value '${mode}'; expected off, warn, or strict" >&2
            exit 8
            ;;
    esac

    [[ "${mode}" != "off" ]] || return 0
    command -v getenforce >/dev/null 2>&1 || return 0
    [[ "$(getenforce 2>/dev/null || true)" == "Enforcing" ]] || return 0

    file_type="$(selinux_file_type "${host_executable}" || true)"
    [[ -n "${file_type}" ]] || return 0

    if [[ -n "${expected_type}" && "${file_type}" != "${expected_type}" ]]; then
        selinux_preflight_problem \
            "${mode}" \
            "host executable type '${file_type}' does not match UE4SS_EXPECTED_SELINUX_TYPE='${expected_type}'"
        return 0
    fi

    case "${file_type}" in
        user_home_t|home_root_t|default_t|unlabeled_t)
            selinux_preflight_problem \
                "${mode}" \
                "host executable type '${file_type}' does not identify a scoped UE4SS SELinux entrypoint"
            ;;
    esac
}

host_executable=""
if [[ "${1:-}" == "--host-executable" ]]; then
    if [[ $# -lt 3 ]]; then
        usage
        exit 2
    fi
    host_executable="$2"
    shift 2
fi
if [[ $# -lt 1 ]]; then
    usage
    exit 2
fi

target_executable="$1"
shift

if [[ ! -f "${ue4ss_library}" ]]; then
    echo "UE4SS launcher: libUE4SS.so not found: ${ue4ss_library}" >&2
    exit 3
fi
if [[ ! -f "${target_executable}" || ! -x "${target_executable}" ]]; then
    echo "UE4SS launcher: target executable not found or not executable: ${target_executable}" >&2
    exit 4
fi
if [[ -z "${host_executable}" ]]; then
    host_executable="${target_executable}"
    if ! is_elf_file "${host_executable}"; then
        echo "UE4SS launcher: script commands require --host-executable <ELF executable>" >&2
        exit 5
    fi
fi
if [[ ! -f "${host_executable}" || ! -x "${host_executable}" ]]; then
    echo "UE4SS launcher: host executable not found or not executable: ${host_executable}" >&2
    exit 6
fi
if ! is_elf_file "${host_executable}"; then
    echo "UE4SS launcher: host executable is not an ELF file: ${host_executable}" >&2
    exit 7
fi

selinux_preflight

export UE4SS_LAUNCH_TARGET_EXE="$(canonical_path "${host_executable}")"
if [[ -v LD_PRELOAD ]]; then
    export UE4SS_LAUNCH_LD_PRELOAD_WAS_SET=1
    export UE4SS_LAUNCH_ORIGINAL_LD_PRELOAD="${LD_PRELOAD}"
else
    export UE4SS_LAUNCH_LD_PRELOAD_WAS_SET=0
    export UE4SS_LAUNCH_ORIGINAL_LD_PRELOAD=""
fi

export UE4SS_MODULE_PATH="${ue4ss_library}"
preload_path="${ue4ss_library}"
if [[ "${preload_path}" == *[[:space:]:]* ]]; then
    exec {ue4ss_preload_fd}<"${ue4ss_library}"
    preload_path="/proc/self/fd/${ue4ss_preload_fd}"
fi

if [[ -n "${LD_PRELOAD:-}" ]]; then
    export LD_PRELOAD="${preload_path}:${LD_PRELOAD}"
else
    export LD_PRELOAD="${preload_path}"
fi

exec "${target_executable}" "$@"
