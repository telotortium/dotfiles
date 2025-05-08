# -*- mode: sh -*-
# shellcheck shell=dash
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

# Quote a string for use by eval.
shell_quote() {
  # $1 = the raw string
  # prints the safely-quoted version to stdout
  # Use `\x27` in awk to print single quotes around string.
  printf '%s' "$1" \
    | sed "s/'/'\\\\''/g" \
    | awk '{ printf("\x27%s\x27", $0); }'
}

# pathvarmunge VAR DIR [AFTER]
# Add DIR to pathlike-variable VAR if not already present. If AFTER="after",
# add it to the end, else to the beginning.
# Based on pathmunge function present in Fedora/RHEL (among other systems), but
# generalized to set any type of variable.
pathvarmunge () {
    eval "var=$(shell_quote "$1")"
    eval "dir=$(shell_quote "$2")"
    eval "after=$(shell_quote "$3")"
    # If VAR is currently empty, just set it to DIR and return.
    # shellcheck disable=SC2154
    if [ -z "$(eval "echo \${${var}+x}")" ]; then
        eval "$var=$(shell_quote "$dir")"
        return 0
    fi
    # Quoting is correct to set `varval` to the value of the variable whose
    # name is stored in `var`.
    eval varval="$( eval shell_quote "\"\$${var}\"" )"
    # shellcheck disable=SC2154
    if ! echo "$varval" | grep -Eq "(^|:)$dir($|:)" ; then
       if [ "$after" = "after" ] ; then
           eval "$var=$(shell_quote "$varval:$dir")"
       else
           eval "$var=$(shell_quote "$dir:$varval")"
       fi
    fi
}

# source_if_exists FILE [ARGS...]
# Source FILE if it exists, passing ARGS if given.
source_if_exists () {
    # shellcheck disable=SC1090
    [ -f "$1" ] && . "$@"
}

# Set proxy environment variables
# Based on https://gist.github.com/yougg/5d2b3353fc5e197a0917aae0b3287d64.
# Takes one argument "HOST:PORT". Assumed to be a SOCKS5 proxy (as set up
# by SSH, for example).
proxy_setup () {
    export http_proxy="socks5://${1}"
    export https_proxy="$http_proxy"
    export ftp_proxy="$http_proxy"
    export rsync_proxy="$http_proxy"
    export all_proxy="$http_proxy"
    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$http_proxy"
    export FTP_PROXY="$http_proxy"
    export RSYNC_PROXY="$http_proxy"
    export ALL_PROXY="$http_proxy"
    export no_proxy="127.0.0.1,localhost,.localdomain.com"
    export NO_PROXY="$no_proxy"
}
