#!/usr/bin/env bash

set -euo pipefail

repo_root="$(
    git rev-parse --show-toplevel
)"

submodule_root="${repo_root}/deps/first/Unreal"

patches=(
    "${repo_root}/patches/uepseudo/0001-fix-case-preserving-fname-constructor.patch"
)

if [[ ! -d "${submodule_root}/.git" ]] &&
   [[ ! -f "${submodule_root}/.git" ]]; then
    echo "ERROR: UEPseudo submodule is not initialized:"
    echo "${submodule_root}"
    exit 1
fi

for patch in "${patches[@]}"; do
    echo "Processing UEPseudo patch: $(basename "${patch}")"

    if git -C "${submodule_root}" apply --check "${patch}"; then
        git -C "${submodule_root}" apply "${patch}"
        echo "Applied: $(basename "${patch}")"
    elif git -C "${submodule_root}" apply --reverse --check "${patch}"; then
        echo "Already applied: $(basename "${patch}")"
    else
        echo "ERROR: patch cannot be applied or reversed cleanly:"
        echo "${patch}"
        exit 1
    fi
done
