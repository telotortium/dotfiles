#!/usr/bin/env bash

set -eu -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
submodules_status=$(git submodule status)
# Sed commands:
# 1. Find submodules not up-to-date (the status lines that don't start with
#    ' ').
# 2. Remove leading commit hash.
# 3. Remove trailing ref name (last space-separated word in line, in
#    parentheses.
submodules_outdated=$(echo -E "$submodules_status" | \
    sed -e '/^ /d' -e 's/^[^ ]* //' -e 's/ ([^ ]*)$//') || true
if [[ -n "${submodules_outdated}" ]]; then
    printf '%s\n\n%s\n\nRun the following commands to fix them:\n\n%s\n' \
        'The following git submodules are out of date:' \
        "${submodules_outdated}" \
        "$(sed 's/^/git submodule update --init /' \
            <<<"${submodules_outdated}")" 1>&2
    exit 1
fi
