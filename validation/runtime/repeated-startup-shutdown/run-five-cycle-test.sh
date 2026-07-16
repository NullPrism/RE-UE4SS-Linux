#!/usr/bin/env bash

set -uo pipefail

cycles="${1:-5}"
launcher="/home/palworld-2/start-palworld-test-ue4ss.sh"
server_elf="/home/palworld-2/palserver/Pal/Binaries/Linux/PalServer-Linux-Shipping"
ue4ss_root="/home/palworld-2/loader-under-test/current"
ue4ss_log="${ue4ss_root}/UE4SS.log"
crash_dir="${ue4ss_root}/UE4SS-crashes"
mod_script="${ue4ss_root}/Mods/NullPrismLinuxAcceptance/Scripts/main.lua"
audit_root="/home/palworld-2/loader-under-test/audit"
prefix="[NullPrismRepeatedStartupShutdown]"
expected_loader_sha256="1f1459b01ff3de75ea637097c0a1ef7bf141e2b2b93369351b22c16105ec1f73"
ports=(8212 27016)

[[ "$EUID" -eq 0 ]] || { echo 'ERROR: run as root.' >&2; exit 1; }
[[ "$cycles" =~ ^[1-9][0-9]*$ ]] || { echo 'ERROR: cycle count must be positive.' >&2; exit 1; }

find_server_pid()
{
    local pid
    while read -r pid; do
        [[ -n "$pid" ]] || continue
        if [[ "$(readlink -f "/proc/${pid}/exe" 2>/dev/null || true)" == "$server_elf" ]]; then
            echo "$pid"
            return 0
        fi
    done < <(pgrep -u palworld-2 -f "$server_elf" 2>/dev/null || true)
    return 1
}

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

ports_clear()
{
    local port
    for port in "${ports[@]}"; do
        port_up "$port" && return 1
    done
    return 0
}

pgid_exists()
{
    local pgid="$1"
    ps -eo pgid= | awk -v pgid="$pgid" '$1==pgid {f=1} END {exit(f?0:1)}'
}

wait_for_server_and_group_exit()
{
    local pgid="$1"
    local timeout_seconds="$2"
    local attempt

    for ((attempt = 1; attempt <= timeout_seconds; attempt++)); do
        if [[ -z "$(find_server_pid || true)" ]] && ! pgid_exists "$pgid"; then
            return 0
        fi
        sleep 1
    done

    return 1
}

controller_is_running()
{
    local controller_pid="$1"
    local state

    kill -0 "$controller_pid" 2>/dev/null || return 1

    state="$(ps -o stat= -p "$controller_pid" 2>/dev/null | awk '{print $1}')"
    [[ -n "$state" && "$state" != Z* ]]
}

reap_controller()
{
    local controller_pid="$1"
    local timeout_seconds="${2:-30}"
    local attempt

    for ((attempt = 1; attempt <= timeout_seconds; attempt++)); do
        controller_is_running "$controller_pid" || break
        sleep 1
    done

    if controller_is_running "$controller_pid"; then
        echo "Controller PID ${controller_pid} did not exit; sending SIGTERM."
        kill -TERM "$controller_pid" 2>/dev/null || true

        for attempt in {1..5}; do
            controller_is_running "$controller_pid" || break
            sleep 1
        done
    fi

    if controller_is_running "$controller_pid"; then
        echo "Controller PID ${controller_pid} survived SIGTERM; sending SIGKILL."
        kill -KILL "$controller_pid" 2>/dev/null || true
    fi

    if wait "$controller_pid"; then
        controller_status=0
    else
        controller_status="$?"
    fi
}

avc_count()
{
    ausearch -m AVC,USER_AVC -c PalServer-Linux --raw 2>/dev/null |
        grep -c '^type=AVC' || true
}

active_controller=""
active_pgid=""

force_cleanup()
{
    local attempt

    if [[ -n "$active_pgid" ]] && pgid_exists "$active_pgid"; then
        kill -TERM -- "-${active_pgid}" 2>/dev/null || true
        for attempt in {1..10}; do
            pgid_exists "$active_pgid" || break
            sleep 1
        done
        pgid_exists "$active_pgid" && kill -KILL -- "-${active_pgid}" 2>/dev/null || true
    fi

    if [[ -n "$active_controller" ]] && kill -0 "$active_controller" 2>/dev/null; then
        kill -TERM "$active_controller" 2>/dev/null || true
    fi
}

interrupt_cleanup()
{
    force_cleanup
    exit 130
}

trap force_cleanup EXIT
trap interrupt_cleanup INT TERM

for path in "$launcher" "$server_elf" "$ue4ss_root/libUE4SS.so" "$mod_script"; do
    [[ -e "$path" ]] || { echo "ERROR: missing $path" >&2; exit 1; }
done

existing_pid="$(find_server_pid || true)"
[[ -z "$existing_pid" ]] || { echo "ERROR: PalServer already running: $existing_pid" >&2; exit 1; }
ports_clear || { echo 'ERROR: test ports are occupied.' >&2; exit 1; }

loader_sha256="$(sha256sum "$ue4ss_root/libUE4SS.so" | awk '{print $1}')"
[[ "$loader_sha256" == "$expected_loader_sha256" ]] || {
    echo 'ERROR: loader checksum differs from validated candidate.' >&2
    exit 1
}

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
audit_dir="${audit_root}/repeated-startup-shutdown-${timestamp}"
install -d -m 0750 -o palworld-2 -g palworld-2 "$audit_dir"

{
    echo "CapturedUTC=$timestamp"
    echo "Cycles=$cycles"
    echo "LoaderTarget=$(readlink -f "$ue4ss_root")"
    sha256sum "$ue4ss_root/libUE4SS.so" "$server_elf" "$launcher" "$mod_script"
} > "$audit_dir/test-metadata.txt"

if find "$crash_dir" -maxdepth 1 -type f -size +0c -print -quit | grep -q .; then
    cp -a "$crash_dir" "$audit_dir/preexisting-crashes"
fi

printf 'cycle\tstartup_seconds\tshutdown_seconds\tshutdown_sigints\tcontroller_status\tresult\n' > "$audit_dir/cycles.tsv"
failures=0

for cycle in $(seq 1 "$cycles"); do
    cycle_dir="${audit_dir}/$(printf 'cycle-%02d' "$cycle")"
    install -d -m 0750 -o palworld-2 -g palworld-2 "$cycle_dir"

    echo
    echo "===== Cycle ${cycle}/${cycles} ====="

    rm -f "$ue4ss_log"
    install -d -m 0750 -o palworld-2 -g palworld-2 "$crash_dir"
    find "$crash_dir" -maxdepth 1 -type f -delete

    avc_before="$(avc_count)"
    start_ns="$(date +%s%N)"

    runuser -u palworld-2 -- \
        setsid --fork --wait "$launcher" \
        > "$cycle_dir/server-console.log" 2>&1 &

    active_controller="$!"
    echo "$active_controller" > "$cycle_dir/controller.pid"

    server_pid=""
    for attempt in {1..90}; do
        server_pid="$(find_server_pid || true)"
        [[ -n "$server_pid" ]] && break
        kill -0 "$active_controller" 2>/dev/null || break
        sleep 1
    done

    cycle_failed=0
    ready=0
    domain_ok=0
    shutdown_clean=0
    ports_released=0
    startup_seconds=-1
    shutdown_seconds=-1
    controller_status=-1
    shutdown_signal_count=0

    if [[ -z "$server_pid" ]]; then
        echo 'ERROR: PalServer process was not created.' | tee "$cycle_dir/failure.txt"
        cycle_failed=1
        force_cleanup
    else
        active_pgid="$(ps -o pgid= -p "$server_pid" | tr -d '[:space:]')"
        echo "$server_pid" > "$cycle_dir/server.pid"
        echo "$active_pgid" > "$cycle_dir/process-group.id"

        echo "PalServer PID=${server_pid} PGID=${active_pgid}"
        echo 'Waiting for Lua PASS marker and both UDP listeners...'

        marker=0
        game_port=0
        query_port=0

        for attempt in {1..180}; do
            marker=0
            game_port=0
            query_port=0

            grep -Fq "${prefix} RESULT=PASS" "$ue4ss_log" 2>/dev/null &&
                marker=1

            port_up 8212 &&
                game_port=1

            port_up 27016 &&
                query_port=1

            if (( marker && game_port && query_port )); then
                ready=1
                break
            fi

            kill -0 "$server_pid" 2>/dev/null ||
                break

            sleep 1
        done

        {
            echo "LuaPassMarker=$marker"
            echo "GamePort8212=$game_port"
            echo "QueryPort27016=$query_port"
        } > "$cycle_dir/readiness.txt"

        echo             "Readiness state: marker=${marker} " \
            "game_port=${game_port} " \
            "query_port=${query_port}"

        startup_seconds="$(( ($(date +%s%N) - start_ns) / 1000000000 ))"

        if (( ready )); then
            echo "Startup readiness PASS after ${startup_seconds}s."
        else
            echo "Startup readiness FAILED after ${startup_seconds}s."
        fi

        ps -e \
            -o pid,ppid,pgid,sid,user,lstart,etime,%cpu,%mem,rss,vsz,cmd \
            > "$cycle_dir/processes-before-shutdown.txt"

        selinux_context="$(
            tr -d '\000' < "/proc/${server_pid}/attr/current" 2>/dev/null ||
                true
        )"

        printf '%s\n' "$selinux_context" \
            > "$cycle_dir/selinux-process.txt"

        ss -lunp \
            > "$cycle_dir/listeners-before-shutdown.txt"

        if [[ "$selinux_context" == *":palworld_ue4ss_t:"* ]]; then
            domain_ok=1
        fi

        (( ready )) || { echo 'ERROR: startup readiness failed.' | tee -a "$cycle_dir/failure.txt"; cycle_failed=1; }
        (( domain_ok )) || { echo 'ERROR: SELinux domain was not palworld_ue4ss_t.' | tee -a "$cycle_dir/failure.txt"; cycle_failed=1; }

        current_loader_sha256="$(sha256sum "$ue4ss_root/libUE4SS.so" | awk '{print $1}')"
        if [[ "$current_loader_sha256" != "$expected_loader_sha256" ]]; then
            echo 'ERROR: loader checksum changed.' | tee -a "$cycle_dir/failure.txt"
            cycle_failed=1
        fi

        shutdown_start_ns="$(date +%s%N)"
        shutdown_signal_count=1

        echo "Sending first SIGINT to process group ${active_pgid}."
        kill -INT -- "-${active_pgid}" 2>/dev/null || true

        if wait_for_server_and_group_exit "$active_pgid" 15; then
            shutdown_clean=1
        else
            shutdown_signal_count=2
            echo 'Server remains active after 15s; sending second SIGINT.'
            kill -INT -- "-${active_pgid}" 2>/dev/null || true

            if wait_for_server_and_group_exit "$active_pgid" 60; then
                shutdown_clean=1
            fi
        fi

        shutdown_seconds="$(( ($(date +%s%N) - shutdown_start_ns) / 1000000000 ))"

        if (( shutdown_clean )); then
            echo "Graceful shutdown PASS after ${shutdown_seconds}s using ${shutdown_signal_count} SIGINT signal(s)."
        else
            echo 'ERROR: shutdown did not complete after two SIGINT signals; forcing cleanup.' | tee -a "$cycle_dir/failure.txt"
            cycle_failed=1
            force_cleanup
        fi
    fi

    if [[ -n "$active_controller" ]]; then
        reap_controller "$active_controller" 30
    fi
    active_controller=""
    active_pgid=""

    for attempt in {1..60}; do
        if ports_clear; then
            ports_released=1
            break
        fi
        sleep 1
    done

    (( ports_released )) || { echo 'ERROR: test ports were not released.' | tee -a "$cycle_dir/failure.txt"; cycle_failed=1; }
    [[ -z "$(find_server_pid || true)" ]] || { echo 'ERROR: PalServer survived shutdown.' | tee -a "$cycle_dir/failure.txt"; cycle_failed=1; }

    crash_count="$(find "$crash_dir" -type f -size +0c | wc -l)"
    avc_after="$(avc_count)"
    avc_delta="$((avc_after - avc_before))"

    (( crash_count == 0 )) || { echo "ERROR: ${crash_count} nonempty crash file(s)." | tee -a "$cycle_dir/failure.txt"; cycle_failed=1; }
    (( avc_delta == 0 )) || { echo "ERROR: ${avc_delta} new SELinux AVC record(s)." | tee -a "$cycle_dir/failure.txt"; cycle_failed=1; }

    [[ -f "$ue4ss_log" ]] && cp -a "$ue4ss_log" "$cycle_dir/UE4SS.log"
    cp -a "$crash_dir" "$cycle_dir/UE4SS-crashes"
    ss -lunp > "$cycle_dir/listeners-after-shutdown.txt"
    ausearch -m AVC,USER_AVC -c PalServer-Linux --raw > "$cycle_dir/avc-all.txt" 2>/dev/null || true

    {
        echo "Ready=$ready"
        echo "SELinuxDomainOK=$domain_ok"
        echo "StartupSeconds=$startup_seconds"
        echo "GracefulShutdown=$shutdown_clean"
        echo "ShutdownSeconds=$shutdown_seconds"
        echo "ShutdownSIGINTCount=$shutdown_signal_count"
        echo "PortsReleased=$ports_released"
        echo "ControllerStatus=$controller_status"
        echo "NonemptyCrashFiles=$crash_count"
        echo "NewSELinuxAVCs=$avc_delta"
    } > "$cycle_dir/summary.txt"

    if (( cycle_failed == 0 )); then
        result=PASS
    else
        result=FAIL
        failures=$((failures + 1))
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cycle" "$startup_seconds" "$shutdown_seconds" "$shutdown_signal_count" "$controller_status" "$result" \
        >> "$audit_dir/cycles.tsv"

    echo "Cycle ${cycle}: ${result}"
done

{
    echo "RequestedCycles=$cycles"
    echo "PassedCycles=$((cycles - failures))"
    echo "FailedCycles=$failures"
    (( failures == 0 )) && echo 'RESULT=PASS' || echo 'RESULT=FAIL'
} > "$audit_dir/validation-summary.txt"

cp -a "$launcher" "$audit_dir/"
cp -a "$mod_script" "$audit_dir/stability-main.lua"
cp -a "$0" "$audit_dir/run-five-cycle-test.sh"

(
    cd "$audit_dir"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

chown -R palworld-2:palworld-2 "$audit_dir"
archive="${audit_dir}.tar.gz"
tar -C "$(dirname "$audit_dir")" -czf "$archive" "$(basename "$audit_dir")"
(
    cd "$(dirname "$archive")"
    sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256"
)
chown palworld-2:palworld-2 "$archive" "${archive}.sha256"

printf '\n%s\n' '=== Final result ==='
cat "$audit_dir/validation-summary.txt"
printf '\nAudit directory: %s\nAudit archive:   %s\n' "$audit_dir" "$archive"
cat "${archive}.sha256"

trap - EXIT INT TERM
(( failures == 0 ))
