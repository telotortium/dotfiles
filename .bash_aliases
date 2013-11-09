#!/bin/bash
# Basic ls aliases
unalias ls &> /dev/null
alias l='ls -CF'
alias la='ls -lA'
alias ll='ls -l'
alias dir='ls --format=vertical -F'
alias vdir='ls --format=long -F'
# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors -b`"

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
fi

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
if test $(ls -i $(readlink -f $(which vi)) | cut -d' ' -f1) = \
    $(ls -i $(readlink -f $(which vim)) | cut -d' ' -f1); then
    alias vi="vim -Xu NONE +'set bg=dark'"
    alias view="vim -RXu NONE +'set bg=dark'"
fi
if [ -f /etc/fedora-release ]; then
    vim=vimx
else
    vim=vim
fi
# Disable X forwarding with Vim by default if we're connecting remotely
vim_withX ()
{
    "$vim" "$@"
}
vim_noX ()
{
    "$vim" -X "$@"
}
if test -n "$SSH_CONNECTION"; then
    alias vim="vim_noX"
    alias vimx="vim_withX"
else
    alias vim="vim_withX"
    alias vimx="vim_withX"
fi

# Easy access to editor
alias edit="$VISUAL"

# Fix crontab with gvim
if echo $VISUAL | grep -q gvim; then
    alias crontab="VISUAL=$VISUAL\ --nofork crontab -i "
else
    alias crontab="crontab -i "
fi

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
function cd ()
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

function disowner ()
{
    "$*" &> /dev/null & disown
}

# Colored manpages. If man doesn't work, use help instead (for shell builtins)
man () {
    TERMINFO=~/.terminfo/ LESS=XC TERM=mostlike PAGER=less `which man` $@ || (help $@ &> /dev/null && help $@ | less)
}
alias perldoc="TERMINFO=~/.terminfo/ LESS=XC TERM=mostlike PAGER=less perldoc"


# Safetly/convenience aliases for cp, mv, rm
function cp () {
    if [ $# -eq 1 ]; then
        `which cp` -i "$1" .
    else
        `which cp` -i "$@"
    fi
}
function mv () {
    if [ $# -eq 1 ]; then
        `which mv` -i "$1" .
    else
        `which mv` -i "$@"
    fi
}
alias rm="rm -I"

# Use POSIX-extended regexes in find
function refind () {
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
alias perl="perl -w"
which ack-grep &>/dev/null && alias ack=ack-grep

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
