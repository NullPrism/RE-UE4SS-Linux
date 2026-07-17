foreach(required_variable
        UE4SS_LIBRARY
        PROBE_EXECUTABLE
        SETTINGS_TEMPLATE
        STAGE_DIRECTORY)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "Missing required variable: ${required_variable}")
    endif()
endforeach()

file(REMOVE_RECURSE "${STAGE_DIRECTORY}")
file(MAKE_DIRECTORY "${STAGE_DIRECTORY}/UE4SS_Signatures")

get_filename_component(
    ue4ss_library_name
    "${UE4SS_LIBRARY}"
    NAME
)

file(
    COPY "${UE4SS_LIBRARY}"
    DESTINATION "${STAGE_DIRECTORY}"
)

file(
    READ "${SETTINGS_TEMPLATE}"
    settings_contents
)

string(
    REPLACE
    "SecondsToScanBeforeGivingUp = 30"
    "SecondsToScanBeforeGivingUp = 0"
    settings_contents
    "${settings_contents}"
)

string(
    REPLACE
    "ConsoleEnabled = 1"
    "ConsoleEnabled = 0"
    settings_contents
    "${settings_contents}"
)

file(
    WRITE
    "${STAGE_DIRECTORY}/UE4SS-settings.ini"
    "${settings_contents}"
)

file(
    WRITE
    "${STAGE_DIRECTORY}/UE4SS_Signatures/GUObjectArray.lua"
    [=[
function Register()
    return "DE AD BE EF FE ED FA CE 01 23 45 67 89 AB CD EF"
end

function OnMatchFound(matchAddress)
    return matchAddress
end
]=]
)

set(
    staged_ue4ss
    "${STAGE_DIRECTORY}/${ue4ss_library_name}"
)

set(
    ue4ss_log
    "${STAGE_DIRECTORY}/UE4SS.log"
)

# A marker-free preload must load the shared object without initializing
# UE4SS or modifying the shared log.
file(
    WRITE
    "${ue4ss_log}"
    "UE4SS_MISSING_TARGET_SENTINEL\n"
)

file(
    SHA256
    "${ue4ss_log}"
    skipped_log_sha256_before
)

execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E env
        "--unset=UE4SS_DISABLE_AUTO_START"
        "--unset=UE4SS_LAUNCH_TARGET_EXE"
        "--unset=UE4SS_LAUNCH_LD_PRELOAD_WAS_SET"
        "--unset=UE4SS_LAUNCH_ORIGINAL_LD_PRELOAD"
        "--unset=UE4SS_MODULE_PATH"
        "--unset=UE4SS_ALLOW_LEGACY_START"
        "LD_PRELOAD=${staged_ue4ss}"
        "UE4SS_DIAGNOSE=1"
        "${PROBE_EXECUTABLE}"
    RESULT_VARIABLE skipped_probe_result
    OUTPUT_VARIABLE skipped_probe_stdout
    ERROR_VARIABLE skipped_probe_stderr
    TIMEOUT 5
)

set(
    skipped_probe_output
    "${skipped_probe_stdout}\n${skipped_probe_stderr}"
)

if(NOT skipped_probe_result EQUAL 0)
    message(
        FATAL_ERROR
        "Missing-target probe exited with ${skipped_probe_result}:\n"
        "${skipped_probe_output}"
    )
endif()

if(NOT skipped_probe_output MATCHES "UE4SS_FAIL_SOFT_PROBE_READY")
    message(
        FATAL_ERROR
        "Missing-target probe did not reach its ready marker:\n"
        "${skipped_probe_output}"
    )
endif()

if(NOT skipped_probe_output MATCHES
       "DIAG: startup_skipped reason=missing_target")
    message(
        FATAL_ERROR
        "Missing-target probe did not report fail-closed startup:\n"
        "${skipped_probe_output}"
    )
endif()

file(
    SHA256
    "${ue4ss_log}"
    skipped_log_sha256_after
)

if(NOT skipped_log_sha256_before STREQUAL skipped_log_sha256_after)
    message(
        FATAL_ERROR
        "Missing-target preload modified UE4SS.log"
    )
endif()

file(REMOVE "${ue4ss_log}")

# Explicit legacy opt-in retains the existing fail-soft initialization test.
execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E env
        "--unset=UE4SS_DISABLE_AUTO_START"
        "--unset=UE4SS_LAUNCH_TARGET_EXE"
        "--unset=UE4SS_LAUNCH_LD_PRELOAD_WAS_SET"
        "--unset=UE4SS_LAUNCH_ORIGINAL_LD_PRELOAD"
        "--unset=UE4SS_MODULE_PATH"
        "LD_PRELOAD=${staged_ue4ss}"
        "UE4SS_DIAGNOSE=1"
        "UE4SS_ALLOW_LEGACY_START=1"
        "${PROBE_EXECUTABLE}"
    RESULT_VARIABLE probe_result
    OUTPUT_VARIABLE probe_stdout
    ERROR_VARIABLE probe_stderr
    TIMEOUT 5
)

set(
    probe_output
    "${probe_stdout}\n${probe_stderr}"
)

if(NOT probe_result EQUAL 0)
    message(
        FATAL_ERROR
        "Legacy fail-soft probe exited with ${probe_result}:\n"
        "${probe_output}"
    )
endif()

if(NOT probe_output MATCHES "UE4SS_FAIL_SOFT_PROBE_READY")
    message(
        FATAL_ERROR
        "Legacy fail-soft probe did not reach its ready marker:\n"
        "${probe_output}"
    )
endif()

if(NOT EXISTS "${ue4ss_log}")
    message(
        FATAL_ERROR
        "Legacy fail-soft probe did not create UE4SS.log"
    )
endif()

file(
    READ
    "${ue4ss_log}"
    ue4ss_log_contents
)

if(NOT ue4ss_log_contents MATCHES "PS scan timed out")
    message(
        FATAL_ERROR
        "UE4SS.log did not record the expected signature failure"
    )
endif()

file(
    SHA256
    "${PROBE_EXECUTABLE}"
    probe_sha256
)

foreach(expected_diagnostic
        "DIAG: executable_sha256=${probe_sha256}"
        "DIAG: glibc_version="
        "DIAG: glibcxx_ceiling=GLIBCXX_"
        "DIAG: module=MainExe range=0x"
        "DIAG: engine_version=unresolved"
        "DIAG: signature=GUObjectArray status=skipped address=0x0"
        "DIAG: inactive_reason=PS scan timed out")
    string(
        FIND
        "${ue4ss_log_contents}"
        "${expected_diagnostic}"
        diagnostic_position
    )

    if(diagnostic_position EQUAL -1)
        message(
            FATAL_ERROR
            "UE4SS.log did not contain '${expected_diagnostic}'"
        )
    endif()
endforeach()

file(
    SIZE
    "${ue4ss_log}"
    ue4ss_log_size
)

if(ue4ss_log_size GREATER 1048576)
    message(
        FATAL_ERROR
        "Fail-soft signature scanning produced an excessive "
        "${ue4ss_log_size}-byte log"
    )
endif()

file(REMOVE_RECURSE "${STAGE_DIRECTORY}")
