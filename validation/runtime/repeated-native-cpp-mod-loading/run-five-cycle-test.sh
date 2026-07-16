#!/usr/bin/env bash

set -euo pipefail

requested_cycles="${1:-5}"

if [[ ! "$requested_cycles" =~ ^[1-9][0-9]*$ ]]; then
    echo 'ERROR: cycle count must be a positive integer.' >&2
    exit 2
fi

launcher="/home/palworld-2/start-palworld-test-ue4ss.sh"
server_elf="/home/palworld-2/palserver/Pal/Binaries/Linux/PalServer-Linux-Shipping"

ue4ss_root="$(
    readlink -f \
        /home/palworld-2/loader-under-test/current
)"

native_mod_root="$ue4ss_root/Mods/NullPrismNativeAcceptance"
native_module="$native_mod_root/dlls/main.so"

acceptance_root="/home/palworld-2/loader-under-test/acceptance"
expected_hash_file="$acceptance_root/native-cpp-mod.sha256"

audit_root="/home/palworld-2/loader-under-test/audit"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
audit_dir="$audit_root/repeated-native-cpp-mod-loading-${timestamp}"

native_prefix='[NullPrismNativeAcceptance]'
expected_loader_hash='1f1459b01ff3de75ea637097c0a1ef7bf141e2b2b93369351b22c16105ec1f73'

passed_cycles=0
failed_cycles=0

current_server_pid=""
current_pgid=""
current_controller_pid=""

port_up()
{
    local port="$1"

    ss -H -lun |
        awk -v port="$port" '
            {
                local_address = $4
                sub(/^.*:/, "", local_address)

                if (local_address == port) {
                    found = 1
                }
            }

            END {
                exit(found ? 0 : 1)
            }
        '
}

server_alive()
{
    [[ -n "$current_server_pid" ]] &&
        kill -0 "$current_server_pid" 2>/dev/null
}

cleanup_current_process()
{
    if server_alive && [[ -n "$current_pgid" ]]; then
        kill -INT -- "-${current_pgid}" 2>/dev/null || true
        sleep 3
    fi

    if server_alive && [[ -n "$current_pgid" ]]; then
        kill -INT -- "-${current_pgid}" 2>/dev/null || true
        sleep 5
    fi

    if server_alive && [[ -n "$current_pgid" ]]; then
        kill -TERM -- "-${current_pgid}" 2>/dev/null || true
        sleep 3
    fi

    if server_alive && [[ -n "$current_pgid" ]]; then
        kill -KILL -- "-${current_pgid}" 2>/dev/null || true
    fi

    if [[ -n "$current_controller_pid" ]]; then
        kill -TERM "$current_controller_pid" 2>/dev/null || true
    fi
}

handle_interrupt()
{
    echo
    echo 'Acceptance harness interrupted; cleaning isolated process group.'
    cleanup_current_process
    exit 130
}

trap handle_interrupt INT TERM

install -d \
    -o palworld-2 \
    -g palworld-2 \
    -m 0750 \
    "$audit_dir"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    cycle \
    startup_seconds \
    shutdown_seconds \
    shutdown_sigints \
    controller_status \
    native_markers \
    crash_files \
    avc_records \
    result \
    > "$audit_dir/cycles.tsv"

if [[ ! -x "$launcher" ]]; then
    echo "ERROR: launcher is unavailable: $launcher" >&2
    exit 1
fi

if [[ ! -f "$native_module" ]]; then
    echo "ERROR: native module is unavailable: $native_module" >&2
    exit 1
fi

if [[ ! -f "$native_mod_root/enabled.txt" ]]; then
    echo "ERROR: native mod enabled.txt is unavailable." >&2
    exit 1
fi

if [[ ! -f "$expected_hash_file" ]]; then
    echo "ERROR: native-mod checksum file is unavailable:" >&2
    echo "$expected_hash_file" >&2
    exit 1
fi

expected_native_hash="$(
    awk 'NF {print $1; exit}' "$expected_hash_file"
)"

actual_native_hash="$(
    sha256sum "$native_module" |
        awk '{print $1}'
)"

actual_loader_hash="$(
    sha256sum "$ue4ss_root/libUE4SS.so" |
        awk '{print $1}'
)"

if [[ "$actual_native_hash" != "$expected_native_hash" ]]; then
    echo 'ERROR: installed native-mod checksum mismatch.' >&2
    echo "Expected: $expected_native_hash" >&2
    echo "Actual:   $actual_native_hash" >&2
    exit 1
fi

if [[ "$actual_loader_hash" != "$expected_loader_hash" ]]; then
    echo 'ERROR: loader checksum mismatch.' >&2
    echo "Expected: $expected_loader_hash" >&2
    echo "Actual:   $actual_loader_hash" >&2
    exit 1
fi

if pgrep -u palworld-2 -f "$server_elf" >/dev/null; then
    echo 'ERROR: isolated PalServer is already running.' >&2
    exit 1
fi

if port_up 8212 || port_up 27016; then
    echo 'ERROR: one or more isolated test ports are occupied.' >&2
    exit 1
fi

for cycle in $(seq 1 "$requested_cycles"); do
    echo
    echo "===== Cycle ${cycle}/${requested_cycles} ====="

    cycle_dir="$audit_dir/cycle-$(printf '%02d' "$cycle")"
    console_log="$cycle_dir/server-console.log"
    text_log="$cycle_dir/server-console.text.log"

    install -d \
        -o palworld-2 \
        -g palworld-2 \
        -m 0750 \
        "$cycle_dir"

    rm -f \
        "$ue4ss_root/UE4SS.log" \
        "$ue4ss_root"/UE4SS-crashes/crash_*.log

    install -d \
        -o palworld-2 \
        -g palworld-2 \
        -m 0750 \
        "$ue4ss_root/UE4SS-crashes"

    cycle_failed=0
    failure_messages=()

    start_ns="$(date +%s%N)"
    audit_start_date="$(date '+%m/%d/%Y')"
    audit_start_time="$(date '+%H:%M:%S')"

    runuser \
        -u palworld-2 \
        -- \
        setsid \
        --fork \
        --wait \
        "$launcher" \
        > "$console_log" \
        2>&1 &

    current_controller_pid=$!

    printf '%s\n' "$current_controller_pid" \
        > "$cycle_dir/controller.pid"

    current_server_pid=""

    for attempt in {1..30}; do
        current_server_pid="$(
            pgrep \
                -n \
                -u palworld-2 \
                -f "$server_elf" ||
            true
        )"

        [[ -n "$current_server_pid" ]] && break
        sleep 1
    done

    if [[ -z "$current_server_pid" ]]; then
        failure_messages+=('PalServer process was not discovered.')
        cycle_failed=1
        current_pgid=""
    else
        current_pgid="$(
            ps \
                -o pgid= \
                -p "$current_server_pid" |
            tr -d '[:space:]'
        )"

        echo \
            "PalServer PID=${current_server_pid} " \
            "PGID=${current_pgid}"

        printf '%s\n' "$current_server_pid" \
            > "$cycle_dir/server.pid"

        printf '%s\n' "$current_pgid" \
            > "$cycle_dir/server.pgid"
    fi

    marker_start=0
    marker_constructor=0
    marker_cpp_loaded=0
    marker_unreal_init=0
    marker_lookup=0
    marker_pass=0
    marker_program_start=0
    game_port=0
    query_port=0
    module_mapped=0
    domain_ok=0
    ready=0

    if (( ! cycle_failed )); then
        echo 'Waiting for native lifecycle markers and both UDP listeners...'

        for attempt in {1..120}; do
            grep -aFq \
                "$native_prefix start_mod export" \
                "$console_log" 2>/dev/null &&
                marker_start=1

            grep -aFq \
                "$native_prefix constructor" \
                "$console_log" 2>/dev/null &&
                marker_constructor=1

            grep -aFq \
                "$native_prefix on_cpp_mods_loaded" \
                "$console_log" 2>/dev/null &&
                marker_cpp_loaded=1

            grep -aFq \
                "$native_prefix on_unreal_init" \
                "$console_log" 2>/dev/null &&
                marker_unreal_init=1

            grep -aFq \
                "$native_prefix StaticFindObject result=valid" \
                "$console_log" 2>/dev/null &&
                marker_lookup=1

            grep -aFq \
                "$native_prefix RESULT=PASS" \
                "$console_log" 2>/dev/null &&
                marker_pass=1

            grep -aFq \
                "$native_prefix on_program_start" \
                "$console_log" 2>/dev/null &&
                marker_program_start=1

            port_up 8212 && game_port=1
            port_up 27016 && query_port=1

            if grep -Fq \
                "$native_module" \
                "/proc/${current_server_pid}/maps" 2>/dev/null; then

                module_mapped=1
            fi

            selinux_context="$(
                tr -d '\000' \
                    < "/proc/${current_server_pid}/attr/current" \
                    2>/dev/null ||
                true
            )"

            if [[ "$selinux_context" == *":palworld_ue4ss_t:"* ]]; then
                domain_ok=1
            fi

            if (( marker_start
                  && marker_constructor
                  && marker_cpp_loaded
                  && marker_unreal_init
                  && marker_lookup
                  && marker_pass
                  && marker_program_start
                  && game_port
                  && query_port
                  && module_mapped
                  && domain_ok )); then

                ready=1
                break
            fi

            server_alive || break
            sleep 1
        done
    fi

    startup_seconds="$(
        echo $(( ($(date +%s%N) - start_ns) / 1000000000 ))
    )"

    {
        echo "StartMod=$marker_start"
        echo "Constructor=$marker_constructor"
        echo "CppModsLoaded=$marker_cpp_loaded"
        echo "UnrealInit=$marker_unreal_init"
        echo "ValidObjectLookup=$marker_lookup"
        echo "PassMarker=$marker_pass"
        echo "ProgramStart=$marker_program_start"
        echo "GamePort8212=$game_port"
        echo "QueryPort27016=$query_port"
        echo "ModuleMapped=$module_mapped"
        echo "SELinuxDomain=$domain_ok"
    } > "$cycle_dir/readiness.txt"

    echo \
        "Readiness state: start=${marker_start} " \
        "constructor=${marker_constructor} " \
        "cpp_loaded=${marker_cpp_loaded} " \
        "unreal_init=${marker_unreal_init} " \
        "lookup=${marker_lookup} " \
        "pass=${marker_pass} " \
        "program_start=${marker_program_start} " \
        "ports=${game_port}/${query_port} " \
        "mapped=${module_mapped} " \
        "domain=${domain_ok}"

    if (( ready )); then
        echo "Startup readiness PASS after ${startup_seconds}s."
    else
        echo "Startup readiness FAILED after ${startup_seconds}s."
        failure_messages+=('Native startup readiness failed.')
        cycle_failed=1
    fi

    tr -d '\000' \
        < "$console_log" \
        > "$text_log"

    grep -F \
        "$native_prefix" \
        "$text_log" \
        > "$cycle_dir/native-lifecycle-markers.txt" ||
        true

    if grep -Eqi \
        'failed to load shared library|failed to find exported|undefined symbol|cannot open shared object|dlopen' \
        "$text_log"; then

        failure_messages+=('Native-loader error was present in console output.')
        cycle_failed=1
    fi

    if [[ -n "$current_server_pid" ]] &&
       [[ -r "/proc/${current_server_pid}/maps" ]]; then

        grep -F \
            "$native_module" \
            "/proc/${current_server_pid}/maps" \
            > "$cycle_dir/native-module-maps.txt" ||
            true

        tr -d '\000' \
            < "/proc/${current_server_pid}/attr/current" \
            > "$cycle_dir/selinux-process.txt" ||
            true
    fi

    ss -lunp \
        > "$cycle_dir/listeners-before-shutdown.txt"

    ps -e \
        -o pid,ppid,pgid,sid,user,lstart,etime,%cpu,%mem,rss,vsz,cmd \
        > "$cycle_dir/processes-before-shutdown.txt"

    crash_count="$(
        find "$ue4ss_root/UE4SS-crashes" \
            -type f \
            -size +0c |
        wc -l
    )"

    if (( crash_count != 0 )); then
        failure_messages+=('One or more nonempty crash files were generated.')
        cycle_failed=1
    fi

    shutdown_start_ns="$(date +%s%N)"
    shutdown_sigints=0

    if server_alive && [[ -n "$current_pgid" ]]; then
        echo "Sending first SIGINT to process group ${current_pgid}."

        kill \
            -INT \
            -- "-${current_pgid}" \
            2>/dev/null ||
            true

        shutdown_sigints=1

        for attempt in {1..15}; do
            server_alive || break
            sleep 1
        done
    fi

    if server_alive && [[ -n "$current_pgid" ]]; then
        echo 'Server remains active after 15s; sending second SIGINT.'

        kill \
            -INT \
            -- "-${current_pgid}" \
            2>/dev/null ||
            true

        shutdown_sigints=2

        for attempt in {1..60}; do
            server_alive || break
            sleep 1
        done
    fi

    shutdown_seconds="$(
        echo $(( ($(date +%s%N) - shutdown_start_ns) / 1000000000 ))
    )"

    if server_alive; then
        failure_messages+=('PalServer did not stop after two SIGINT signals.')
        cycle_failed=1

        kill \
            -TERM \
            -- "-${current_pgid}" \
            2>/dev/null ||
            true

        sleep 5

        if server_alive; then
            kill \
                -KILL \
                -- "-${current_pgid}" \
                2>/dev/null ||
                true
        fi
    else
        echo \
            "Graceful shutdown PASS after ${shutdown_seconds}s " \
            "using ${shutdown_sigints} SIGINT signal(s)."
    fi

    controller_status=0

    if [[ -n "$current_controller_pid" ]]; then
        set +e
        wait "$current_controller_pid"
        controller_status=$?
        set -e
    fi

    if pgrep -u palworld-2 -f "$server_elf" >/dev/null; then
        failure_messages+=('An isolated PalServer process survived shutdown.')
        cycle_failed=1
    fi

    if port_up 8212 || port_up 27016; then
        failure_messages+=('One or more test ports remained active.')
        cycle_failed=1
    fi

    ausearch \
        -m AVC,USER_AVC \
        -ts "$audit_start_date" "$audit_start_time" \
        -c PalServer-Linux \
        > "$cycle_dir/avc.txt" \
        2>/dev/null ||
        true

    avc_count="$(
        grep -Ec '^type=(AVC|USER_AVC)' \
            "$cycle_dir/avc.txt" ||
        true
    )"

    if (( avc_count != 0 )); then
        failure_messages+=('One or more SELinux AVC records were generated.')
        cycle_failed=1
    fi

    tr -d '\000' \
        < "$console_log" \
        > "$text_log"

    uninstall_count="$(
        grep -Fc \
            "$native_prefix uninstall_mod export" \
            "$text_log" ||
        true
    )"

    destructor_count="$(
        grep -Fc \
            "$native_prefix destructor" \
            "$text_log" ||
        true
    )"

    {
        echo "UninstallMarkers=$uninstall_count"
        echo "DestructorMarkers=$destructor_count"
    } > "$cycle_dir/teardown-observation.txt"

    if (( cycle_failed )); then
        printf '%s\n' \
            "${failure_messages[@]}" \
            > "$cycle_dir/failure.txt"

        cycle_result='FAIL'
        failed_cycles=$((failed_cycles + 1))
        echo "Cycle ${cycle}: FAIL"
    else
        cycle_result='PASS'
        passed_cycles=$((passed_cycles + 1))
        echo "Cycle ${cycle}: PASS"
    fi

    native_marker_count="$(
        grep -Fc \
            "$native_prefix" \
            "$cycle_dir/native-lifecycle-markers.txt" ||
        true
    )"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cycle" \
        "$startup_seconds" \
        "$shutdown_seconds" \
        "$shutdown_sigints" \
        "$controller_status" \
        "$native_marker_count" \
        "$crash_count" \
        "$avc_count" \
        "$cycle_result" \
        >> "$audit_dir/cycles.tsv"

    current_server_pid=""
    current_pgid=""
    current_controller_pid=""
done

{
    echo "RequestedCycles=$requested_cycles"
    echo "PassedCycles=$passed_cycles"
    echo "FailedCycles=$failed_cycles"

    if (( passed_cycles == requested_cycles
          && failed_cycles == 0 )); then

        echo 'RESULT=PASS'
    else
        echo 'RESULT=FAIL'
    fi
} > "$audit_dir/validation-summary.txt"

echo
echo '=== Final result ==='
cat "$audit_dir/validation-summary.txt"

{
    echo "CapturedUTC=$timestamp"
    echo "LoaderRoot=$ue4ss_root"
    echo

    sha256sum \
        "$ue4ss_root/libUE4SS.so" \
        "$native_module"
} > "$audit_dir/build-and-module-metadata.txt"

(
    cd "$audit_dir"

    find . \
        -type f \
        ! -name SHA256SUMS \
        -print0 |
    sort -z |
    xargs -0 sha256sum \
        > SHA256SUMS
)

archive="${audit_dir}.tar.gz"

tar \
    -C "$(dirname "$audit_dir")" \
    -czf "$archive" \
    "$(basename "$audit_dir")"

(
    cd "$(dirname "$archive")"

    sha256sum \
        "$(basename "$archive")" \
        > "$(basename "$archive").sha256"
)

chown -R \
    palworld-2:palworld-2 \
    "$audit_dir"

chown \
    palworld-2:palworld-2 \
    "$archive" \
    "${archive}.sha256"

echo
echo "Audit directory: $audit_dir"
echo "Audit archive:   $archive"
cat "${archive}.sha256"

if (( failed_cycles != 0 )); then
    exit 1
fi
