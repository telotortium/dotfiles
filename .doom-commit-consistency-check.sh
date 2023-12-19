#!/usr/bin/env bash

set -eu -o pipefail
set -xv
cd "$(dirname "${BASH_SOURCE[0]}")"
init_el_commit=$(grep "(let.*doom-expected-commit" .doom.d/init.el | sed 's/.*"\(.*\)".*/\1/')
declare -x 1>&2
doom_emacs_d_commit=$(cd doom.emacs.d && env -i "$(which git)" rev-parse HEAD)
if [[ "$init_el_commit" != "$doom_emacs_d_commit" ]]; then
    echo ".doom.d/init.el doom-expected-commit = ${init_el_commit} not consistent with doom.emacs.d Git HEAD ${doom_emacs_d_commit}" 1>&2
    exit 1
fi
