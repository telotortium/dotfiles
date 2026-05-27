# -*- mode: sh -*-
# shellcheck shell=dash
# Common POSIX shell-compatible functions.

# command_on_path CMD
#
# Exit successfully if CMD is an executable (or a shell builtin) or
# unsuccessfully otheriwse.
command_on_path () {
    command -v "$1" >/dev/null 2>&1
}

# Quote a string for use by eval.
shell_quote() {
  # $1 = the raw string
  # prints the safely-quoted version to stdout
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# pathvarmunge VAR DIR [AFTER]
# Add DIR to pathlike-variable VAR if not already present. If AFTER="after",
# add it to the end, else to the beginning.
# Based on pathmunge function present in Fedora/RHEL (among other systems), but
# generalized to set any type of variable.
pathvarmunge () {
    var=$1
    dir=$2
    after=$3
    eval "varval=\${$var-}"
    case ":$varval:" in
        *":$dir:"*) return 0 ;;
    esac
    if [ -z "$varval" ] ; then
        newval=$dir
    elif [ "$after" = "after" ] ; then
        newval=$varval:$dir
    else
        newval=$dir:$varval
    fi
    eval "$var=$(shell_quote "$newval")"
}

# pathvarremove VAR DIR
# Remove DIR from pathlike-variable VAR.
pathvarremove () {
    var=$1
    remove=$2
    eval "varval=\${$var-}"
    newval=$(printf '%s' "$varval" | awk -v RS=: -v target="$remove" '
        length($0) && $0 != target {
            if (out) {
                out = out ":" $0
            } else {
                out = $0
            }
        }
        END { printf "%s", out }
    ')
    eval "$var=$(shell_quote "$newval")"
}

# pathvardedupe VAR
# Remove duplicate and empty entries from pathlike-variable VAR, keeping the
# first instance of each entry.
pathvardedupe () {
    var=$1
    eval "varval=\${$var-}"
    newval=$(printf '%s' "$varval" | awk -v RS=: '
        length($0) && !seen[$0]++ {
            if (out) {
                out = out ":" $0
            } else {
                out = $0
            }
        }
        END { printf "%s", out }
    ')
    eval "$var=$(shell_quote "$newval")"
}

# pathvarensure_front VAR DIR
# Ensure DIR exists in pathlike-variable VAR and is placed at the front.
pathvarensure_front () {
    pathvarremove "$1" "$2"
    pathvarmunge "$1" "$2"
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
