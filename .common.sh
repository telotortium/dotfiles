#!/bin/sh
# Common POSIX shell-compatible functions.

# command_on_path CMD
#
# Exit successfully if CMD is an executable (or a shell builtin) or
# unsuccessfully otheriwse.
command_on_path () {
    # `command -v` is specified by POSIX (see
    # http://pubs.opengroup.org/onlinepubs/009696699/utilities/command.html).
    #
    # Execute shell explicitly in order to avoid loading startup files (e.g.,
    # .env, .bashrc, .kshrc).
    #
    # `$1` is intentionally evaluated in the subshell, not this shell.
    # shellcheck disable=SC2016
    /usr/bin/env sh -c 'command -v "$1" >/dev/null 2>&1' IGNORED "$1"
}
