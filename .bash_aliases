#!/bin/bash
# Basic ls aliases
unalias ls &> /dev/null
alias l='ls -CF'
alias la='ls -lA'
alias ll='ls -l'
alias dir='ls --format=vertical -F'
alias vdir='ls --format=long -F'
# enable color support of ls and also add handy aliases
case "$TERM" in
# No color support
dumb)
    ;;
# Assume color support for other terminals
*)
    # Assume that non-dumb terminals support colors
    eval "$(dircolors -b <(dircolors --print-database \
        | awk "BEGIN { print \"TERM \" \"${TERM}\"; } { print; }"))"

    # Colored paged listing of files
    lspage ()
    {
        ls --color=always "$@" | less -r
    }

    alias ls='ls --color=auto'
    alias l='ls -CF --color=auto'
    alias la='ls -lA --color=auto'
    alias ll='ls -l --color=auto'
    alias dir='ls --color=auto --format=vertical -F'
    alias vdir='ls --color=auto --format=long -F'
    # Set grep to use color automatically
    alias grep="grep --color=auto"
    alias egrep="egrep --color=auto"
    alias fgrep="fgrep --color=auto"
    alias pcregrep="pcregrep --color=auto"
    ;;
esac

# `jobs` command that expands variables (from
# http://stackoverflow.com/questions/9827428/how-to-expand-variables-in-bash-jobs-list
jobs_cmd="jobs"
jobs_expvars ()
{
    local arg jobs_out args_out optl OPTIND OPTARG
    optl=false
    while getopts :pxl arg; do
        case "$arg" in
        # These don't list jobs -- pass through to `jobs`
        p|x)
            "$jobs_cmd" "$@"
            return $?;
            ;;
        l)
            # `-l` takes effect even when combined with `-p`, so it needs
            # different handling.
            optl=true
            ;;
        \?)
            # Don't need to do anything
            ;;
        esac
    done
    jobs_out="$("$jobs_cmd" "$@")"
    rv=$?
    if $optl; then
        # Join on PIDs that appear in the output of `jobs -l`. The PID will
        # then be in column 1.
        jobs_pids="$(join -2 2 <("$jobs_cmd" -p) <("$jobs_cmd" "$@") | \
            awk '{print $1}')"
    else
        jobs_pids="$("$jobs_cmd" -p "$@")"
    fi
    test -z "$jobs_pids" && return $rv  # Done if no background jobs
    paste <(echo "$jobs_out") \
        <(echo "$jobs_pids" | xargs ps -oargs= -p)
    return $rv
}
alias j="jobs_expvars -l"

# If vi is really vim, try to make it fairly lean
# (although I don't want compatible mode at present).
__abs_path () {
    perl -e '
    use Cwd "abs_path";
    for $path (@ARGV) {
        print abs_path($path) . "\n";
    }' "$@"
}
if hash vi 2>/dev/null && hash vim 2>/dev/null \
    && test "$(ls -i "$(__abs_path "$(which vi)")" | cut -d' ' -f1)" = \
    "$(ls -i "$(__abs_path "$(which vim)")" | cut -d' ' -f1)"; then
    alias vi="vim -Xu NONE +'set nocp bg=dark'"
    alias view="vim -RXu NONE +'set nocp bg=dark'"
fi
unset __abs_path

# Try to use a Vim with X compiled in (on Fedora/RedHat that is installed at
# `vimx` instead of the non-X-enabled `vim`), but disable X forwarding with
# Vim by default if we're connecting remotely, since it slows down Vim startup.
if [ -f /etc/fedora-release ] && hash vimx; then
    _vim="command vimx"
else
    _vim="command vim"
fi
if test -n "$SSH_CONNECTION"; then
    alias vim="$_vim -X"
    alias vimx="$_vim"
else
    alias vim="$_vim"
    alias vimx="$_vim"
fi
unset _vim

# Run emacsclient in the background. Run the command using `eval` so that the
# "$@" variable is expanded in the output of `jobs`.
ec () {
    cmd="command emacsclient"
    while [ -n "$1" ]; do
        cmd="$cmd $(printf ' %q' "$1")"
        shift
    done
    eval "$cmd &"
}

# Connect to Vim server to edit file if present, else start server.
vc () {
    local VIM_SERVERNAME=${VIM_SERVERNAME:-VIM}
    local remote_cmd="--remote-tab"
    local args=""
    while [ -n "$1" ]; do
        if [[ $1 =~ --?no(|[-_])tab ]]; then
            remote_cmd="--remote"
        else
            args="$args $(printf ' %q' "$1")"
        fi
        shift
    done
    local cmd="command vim --servername $(printf '%q' ${VIM_SERVERNAME}) ${remote_cmd}"
    eval "$cmd $args"  # Will fork if server exists, otherwise don't want to
}

# Start dummy X server in background -- particularly for Vim, whose server mode
# requires an X server to run but doesn't require windowing.
launch_dummy_X () {
    DUMMY_X_DISPLAY="$1"
    test -n "$1" || return 1
    # Command in startx must be an absolute path to an executable
    if [[ -x /opt/X11/bin/Xvfb ]]; then
        XVFB=${XVFB:-/opt/X11/bin/Xvfb}
    else
        XVFB=${XVFB:-/usr/bin/Xvfb}
    fi
    # Only spawn if server isn't running
    if ! [[ -S /tmp/.X11-unix/"X${DUMMY_X_DISPLAY#*:}" ]]; then
        ( cd /; command startx -- "$XVFB" "${DUMMY_X_DISPLAY:-:50}" \
            -screen 0 1024x768x24 >/dev/null 2>&1 & disown )
    fi
}

# Override vc if connecting via SSH so that Vim connects by default to a Vim
# server running on a dummy X display $DUMMY_X_DISPLAY (the original behavior
# can be obtained using the `vcr` command.
if [[ -z "$DISPLAY" ]] || [[ -n "$SSH_CONNECTION" ]]; then
    eval "__original_$(declare -f vc)"
    vc () {
        local DUMMY_X_DISPLAY=${DUMMY_X_DISPLAY:-:50}
        if ! launch_dummy_X "${DUMMY_X_DISPLAY}"; then
            echo "Launching dummy X on display ${DUMMY_X_DISPLAY} failed" >&2
        fi
        DISPLAY=${DUMMY_X_DISPLAY} __original_vc "$@"
    }
    vcr () {
        __original_vc "$@"
    }
fi

# Easy access to editor
alias edit="$VISUAL"

# Functions to make use of the directory stack easier
# Go backwards in stack
b ()
{
    if [ ! -n "$1" ]; then
        pushd +1
    else
        pushd +"$1"
    fi
}

# Go forwards in stack
f ()
{
    if [ ! -n "$1" ]; then
        pushd -0
    else
        pushd -`dc -e "$1 1 - p"`
    fi
}

alias d="dirs"

# Add directories to the stack when changing directory
cd ()
{
    if [ ! -n "$1" ]; then
        pushd $HOME > /dev/null
    elif [ "$1" = '-' ]; then
        pushd > /dev/null
    else
        pushd "$@" > /dev/null
    fi
}

alias chdir="cd"    # Alternate or DOS name
alias cd.="cd ."    # Sloppy typing alias
alias cd..="cd .."  # Ditto

disowner ()
{
    "$*" &> /dev/null & disown
}

# Colored manpages. If man doesn't work, use help instead (for shell builtins)
if infocmp mostlike &>/dev/null; then
    __MOSTLIKE_TERM_CONFIG="TERMINFO=~/.terminfo/ TERM=mostlike"
else
    __MOSTLIKE_TERM_CONFIG=""
fi
# Use `eval` in order to interpolate `$__MOSTLIKE_TERM_CONFIG` when defining
# the function, instead of when it's run.
eval "
man () {
    LESS=XC PAGER=less $__MOSTLIKE_TERM_CONFIG command man \"\$@\" \
        || (help \"\$@\" &>/dev/null && help \"\$@\" | less)
}
"
alias perldoc="$__MOSTLIKE_TERM_CONFIG LESS=XC PAGER=less perldoc"
unset __MOSTLIKE_TERM_CONFIG


# Safetly/convenience aliases for cp, mv, rm
cp () {
    if [ $# -eq 1 ]; then
        command cp -i "$1" .
    else
        command cp -i "$@"
    fi
}
mv () {
    if [ $# -eq 1 ]; then
        command mv -i "$1" .
    else
        command mv -i "$@"
    fi
}
alias rm="rm -I"

# Use POSIX-extended regexes in find
refind () {
    # If first argument is an option, then proceed as normal;
    # else, the first argument is a directory and needs to be placed in the
    # appropriate spot in the command.
    if [ "${1:0:1}" = "-" ]; then
        find -regextype posix-extended "$@"
    else
        args=("$@")
        find "$1" -regextype posix-extended "${args[@]:1}"
    fi
}

# Aliases for removing certain files quickly
alias clean='rm -f \#* *~ .*~ *.bak .*.bak  *.tmp .*.tmp core a.out'
alias pbsclean='rm -f *.out *.chk *.err *.debug *.pbs '
alias rmtree='rm -r'

# Some useful aliases.
alias h='history'
alias o="xdg-open"
alias pu="pushd"
alias po="popd"
alias screen="/usr/bin/screen"
alias byobu="byobu -S byobu"
hash ack-grep 2>/dev/null && alias ack=ack-grep
hash xdg-open 2>/dev/null && alias open="xdg-open"

# Wake-on-LAN
laplace_wakeonlan () {
    wakeonlan 00:15:F2:D2:23:BA
        wakeonlan 00:15:F2:D2:1F:D2
}

alias csi="rlwrap -pBlue -m -q'\"' csi"


# Function to take over a tmux session (in order to resize the tmux window
# to the size of your terminal.
takeover() {
    # create a temporary session that displays the "how to go back" message
    tmp='takeover temp session'
    if ! tmux has-session -t "$tmp"; then
        tmux new-session -d -s "$tmp"
        tmux set-option -t "$tmp" set-remain-on-exit on
        tmux new-window -kt "$tmp":0 \
            'echo "Use Prefix + L (i.e. ^B L) to return to session.";
             echo "(Press <Enter> to exit)"; read dummy'
    fi

    # switch any clients attached to the target session to the temp session
    session="$1"
    for client in $(tmux list-clients -t "$session" | cut -f 1 -d :); do
        tmux switch-client -c "$client" -t "$tmp"
    done

    # attach to the target session
    tmux attach -t "$session"
}

# Update dotfiles from Git upstream and install any changes
alias dotfiles-update='make -C ~/.dotfiles update'

# I like the Perl version of rename on Linux
hash prename 2>/dev/null && alias rename=prename
hash perl-rename 2>/dev/null && alias rename=perl-rename

# Git diff has pretty colors
alias diff="git diff --no-index --"
