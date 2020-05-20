#!/bin/sh
# Common POSIX shell-compatible functions.

# command_on_path CMD
#
# Exit successfully if CMD is an executable (or a shell builtin) or
# unsuccessfully otheriwse.
command_on_path () {
    {
        cmd=$1
        # Fast path - use hash
        hash "$cmd" || (
            # Slow path, if hash fails or is unsupported.
            set -e
            unalias -a
            x=$(command -v "$cmd")
            # If command starts with `/`, it's not a builtin command.
            test "${x#/}" != "${x}"
        )
    } >/dev/null 2>&1
}
