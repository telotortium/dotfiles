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

# pathvarmunge VAR DIR [AFTER]
# Add DIR to pathlike-variable VAR if not already present. If AFTER="after",
# add it to the end, else to the beginning.
# Based on pathmunge function present in Fedora/RHEL (among other systems), but
# generalized to set any type of variable.
pathvarmunge () {
    typeset "var=$1"
    typeset "varval=$(eval "printf '%q' \"\$${var}\"")"
    typeset "dir=$2"
    typeset "after=$3"
    if [ -z "$varval" -o "$varval" = "''" ]; then
       eval "$var=$(printf '%q' "$dir")"
    elif ! echo "$varval" | egrep -q "(^|:)$dir($|:)" ; then
       if [ "$after" = "after" ] ; then
           eval "$var=$(printf '%q' "$varval:$dir")"
       else
           eval "$var=$(printf '%q' "$dir:$varval")"
       fi
    fi
}

# source_if_exists FILE [ARGS...]
# Source FILE if it exists, passing ARGS if given.
source_if_exists () {
    [ -f "$1" ] && source "$@"
}

# Set proxy environment variables
# Based on https://gist.github.com/yougg/5d2b3353fc5e197a0917aae0b3287d64.
# Takes one argument "HOST:PORT". Assumed to be a SOCKS5 proxy (as set up
# by SSH, for example).
proxy_setup () {
    export http_proxy="socks5://${1}"
    export {https,ftp,rsync,all}_proxy=$http_proxy
    export {HTTP,HTTPS,FTP,RSYNC,ALL}_PROXY=$http_proxy
    export no_proxy="127.0.0.1,localhost,.localdomain.com"
    export NO_PROXY=$no_proxy
}
