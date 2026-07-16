#!/usr/bin/env bash

set -euo pipefail

repo_root="$(
    git rev-parse --show-toplevel
)"

build_root="${UE4SS_BUILD_ROOT:-${repo_root}/build_linux_isolated}"
configuration="Game__Shipping__Linux"

loader_dir="${build_root}/${configuration}/lib64"
loader_library="${loader_dir}/libUE4SS.so"

test_root="${repo_root}/validation/native/cpp-mod-loading"
source_file="${test_root}/src/main.cpp"
export_map="${test_root}/exports.map"
output_dir="${test_root}/build"
output_file="${output_dir}/main.so"

compiler="/usr/bin/clang++"

expected_loader_hash="1f1459b01ff3de75ea637097c0a1ef7bf141e2b2b93369351b22c16105ec1f73"

if [[ ! -x "$compiler" ]]; then
    echo "ERROR: compiler not found: $compiler" >&2
    exit 1
fi

if [[ ! -f "$loader_library" ]]; then
    echo "ERROR: loader library not found:" >&2
    echo "$loader_library" >&2
    exit 1
fi

actual_loader_hash="$(
    sha256sum "$loader_library" |
        awk '{print $1}'
)"

if [[ "$actual_loader_hash" != "$expected_loader_hash" ]]; then
    echo "ERROR: unexpected loader identity." >&2
    echo "Expected: $expected_loader_hash" >&2
    echo "Actual:   $actual_loader_hash" >&2
    exit 1
fi

required_directories=(
    "${repo_root}/UE4SS/include"
    "${repo_root}/UE4SS/generated_include"
    "${repo_root}/deps/first/File/include"
    "${repo_root}/deps/first/Helpers/include"
    "${repo_root}/deps/first/String/include"
    "${repo_root}/deps/first/DynamicOutput/include"
    "${repo_root}/deps/first/Unreal/include"
    "${repo_root}/deps/first/Unreal/generated_include"
    "${repo_root}/deps/first/Unreal/include/Unreal"
    "${repo_root}/deps/first/Unreal/include/Unreal/Core"
    "${repo_root}/deps/first/SinglePassSigScanner/include"
    "${repo_root}/deps/first/Constructs/include"
    "${repo_root}/deps/first/Function/include"
    "${repo_root}/deps/first/ASMHelper/include"
    "${repo_root}/deps/first/LuaMadeSimple/include"
    "${repo_root}/deps/first/LuaRaw/include"
    "${repo_root}/deps/first/IniParser/include"
    "${repo_root}/deps/first/ParserBase/include"
    "${repo_root}/deps/first/JSON/include"
    "${repo_root}/deps/first/Input/include"
    "${repo_root}/deps/first/MProgram/include"
    "${repo_root}/deps/first/ScopedTimer/include"
    "${repo_root}/deps/first/Profiler/include"
    "${build_root}/_deps/fmt-src/include"
    "${build_root}/_deps/glaze-src/include"
    "${build_root}/_deps/polyhook2-src"
    "${build_root}/_deps/zydis-src/include"
    "${build_root}/_deps/zydis-build"
    "${build_root}/_deps/zydis-src/src"
    "${build_root}/_deps/zydis-src/dependencies/zycore/include"
    "${build_root}/_deps/zydis-build/zycore"
    "${build_root}/_deps/zydis-src/dependencies/zycore/src"
    "${build_root}/_deps/polyhook2-src/asmtk/src"
    "${build_root}/_deps/polyhook2-src/asmjit/src"
)

for directory in "${required_directories[@]}"; do
    if [[ ! -d "$directory" ]]; then
        echo "ERROR: required include directory is missing:" >&2
        echo "$directory" >&2
        exit 1
    fi
done

definitions=(
    -DDISABLE_PROFILER
    -DHAS_INPUT
    -DIS_SUPERLUMINAL=0
    -DIS_TRACY=0
    -DLINUX
    -DOVERRIDE_PLATFORM_HEADER_NAME=Linux
    -DPLATFORM_LINUX
    -DPLATFORM_UNIX
    -DRC_ASM_HELPER_BUILD_STATIC
    -DRC_DYNAMIC_OUTPUT_BUILD_STATIC
    -DRC_FILE_BUILD_STATIC
    -DRC_FUNCTION_TIMER_BUILD_STATIC
    -DRC_INI_PARSER_BUILD_STATIC
    -DRC_INPUT_BUILD_STATIC
    -DRC_JSON_BUILD_STATIC
    -DRC_JSON_PARSER_BUILD_STATIC
    -DRC_LUA_MADE_SIMPLE_BUILD_STATIC
    -DRC_LUA_RAW_BUILD_STATIC
    -DRC_LUA_WRAPPER_GENERATOR_BUILD_STATIC
    -DRC_PARSER_BASE_BUILD_STATIC
    -DRC_SINGLE_PASS_SIG_SCANNER_BUILD_STATIC
    -DRC_SINGLE_PASS_SIG_SCANNER_STATIC
    -DRC_STRING_BUILD_STATIC
    -DRC_UNREAL_BUILD_STATIC
    -DUBT_COMPILED_PLATFORM=Linux
    '-DUE4SS_CONFIGURATION="Game__Shipping__Linux"'
    -DUE4SS_LIB_BETA_STARTED=1
    '-DUE4SS_LIB_BUILD_GITSHA="407d14c"'
    -DUE4SS_LIB_IS_BETA=1
    -DUE4SS_LIB_VERSION_BETA=0
    -DUE4SS_LIB_VERSION_HOTFIX=1
    -DUE4SS_LIB_VERSION_MAJOR=3
    -DUE4SS_LIB_VERSION_MINOR=0
    -DUE4SS_LIB_VERSION_PRERELEASE=0
    -DUE_BUILD_SHIPPING
    -DUE_GAME
    -DZYCORE_STATIC_BUILD
    -DZYDIS_STATIC_BUILD
    -Dprintf_s=printf
    -Dwprintf_s=wprintf
    -DASMTK_STATIC
    -DASMJIT_STATIC
)

includes=(
    -I"${repo_root}/UE4SS/include"
    -I"${repo_root}/UE4SS/generated_include"
    -I"${repo_root}/deps/first/File/include"
    -I"${repo_root}/deps/first/Helpers/include"
    -I"${repo_root}/deps/first/String/include"
    -I"${repo_root}/deps/first/DynamicOutput/include"
    -I"${repo_root}/deps/first/Unreal/include"
    -I"${repo_root}/deps/first/Unreal/generated_include"
    -I"${repo_root}/deps/first/Unreal/include/Unreal"
    -I"${repo_root}/deps/first/Unreal/include/Unreal/Core"
    -I"${repo_root}/deps/first/SinglePassSigScanner/include"
    -I"${repo_root}/deps/first/Constructs/include"
    -I"${repo_root}/deps/first/Function/include"
    -I"${repo_root}/deps/first/ASMHelper/include"
    -I"${repo_root}/deps/first/LuaMadeSimple/include"
    -I"${repo_root}/deps/first/LuaRaw/include"
    -I"${repo_root}/deps/first/IniParser/include"
    -I"${repo_root}/deps/first/ParserBase/include"
    -I"${repo_root}/deps/first/JSON/include"
    -I"${repo_root}/deps/first/Input/include"
    -I"${repo_root}/deps/first/MProgram/include"
    -I"${repo_root}/deps/first/ScopedTimer/include"
    -I"${repo_root}/deps/first/Profiler/include"

    -isystem "${build_root}/_deps/fmt-src/include"
    -isystem "${build_root}/_deps/glaze-src/include"
    -isystem "${build_root}/_deps/polyhook2-src"
    -isystem "${build_root}/_deps/zydis-src/include"
    -isystem "${build_root}/_deps/zydis-build"
    -isystem "${build_root}/_deps/zydis-src/src"
    -isystem "${build_root}/_deps/zydis-src/dependencies/zycore/include"
    -isystem "${build_root}/_deps/zydis-build/zycore"
    -isystem "${build_root}/_deps/zydis-src/dependencies/zycore/src"
    -isystem "${build_root}/_deps/polyhook2-src/asmtk/src"
    -isystem "${build_root}/_deps/polyhook2-src/asmjit/src"
)

install -d -m 0750 "$output_dir"
rm -f "$output_file"

"$compiler" \
    "${definitions[@]}" \
    "${includes[@]}" \
    -std=c++23 \
    -O3 \
    -DNDEBUG \
    -fPIC \
    -fms-extensions \
    -fvisibility=hidden \
    -fvisibility-inlines-hidden \
    -Wno-unknown-pragmas \
    -Wno-unused-parameter \
    -Wno-missing-braces \
    "$source_file" \
    -shared \
    -L"$loader_dir" \
    -Wl,--no-as-needed \
    -lUE4SS \
    -static-libstdc++ \
    -static-libgcc \
    -Wl,-z,defs \
    -Wl,--exclude-libs,ALL \
    -Wl,--version-script="$export_map" \
    '-Wl,-rpath,$ORIGIN/../../..' \
    -Wl,-soname,main.so \
    -o "$output_file"

echo "Built native acceptance mod:"
echo "$output_file"

sha256sum "$output_file"
