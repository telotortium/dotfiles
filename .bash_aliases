# -*- mode: sh -*-
# Page following command with color - works with most GNU tools and others
# like them.
cless () {
    "$@" --color=always | less
}
alias cpg=cless  # Not sure which spelling will be more useful.

# Basic ls aliases
unalias ls &> /dev/null
LS_COLOR_FLAG=""
lspage () {
    # shellcheck disable=SC2012
    command ls "$@" | less -r
}
if { command ls --version | grep 'GNU coreutils'; } &>/dev/null; then
    LS_COLOR_FLAG="--color=auto"
    # Assume that non-dumb terminals support colors
    eval "$(dircolors -b <(dircolors --print-database \
        | awk "BEGIN { print \"TERM \" \"${TERM}\"; } { print; }"))"
    lspage () {
        # shellcheck disable=SC2012
        command ls --color=always "$@" | less -r
    }
elif [ $(uname -s) = 'Darwin' ]; then
    LS_COLOR_FLAG="-G"
    lspage () {
        # shellcheck disable=SC2012
        CLICOLOR=1 CLICOLOR_FORCE=1 command ls "$@" | less -r
    }
fi
case "$TERM" in
# No color support
dumb)
    LS_COLOR_FLAG=""
    lspage () {
        # shellcheck disable=SC2012
        command ls "$@" | less -r
    }
    ;;
# Assume color support for other terminals
*)
    ;;
esac
# https://github.com/mgunyho/tere - cd+ls
if command_on_path tere; then
    tere () {
        local result="$(command tere "$@")"
        [ -n "$result" ] && cd -- "$result"
    }
fi
alias ls="ls ${LS_COLOR_FLAG}"
alias l="ls -CF ${LS_COLOR_FLAG}"
alias la="ls -lA ${LS_COLOR_FLAG}"
alias ll="ls -l ${LS_COLOR_FLAG}"
alias dir="ls ${LS_COLOR_FLAG} --format=vertical -F"
alias vdir="ls ${LS_COLOR_FLAG} --format=long -F"
# Set grep to use color automatically
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"
alias pcregrep="pcregrep --color=auto"

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
# `ls -i` to list inode numbers.
# shellcheck disable=SC2012
if command_on_path nvim; then
    _vi_impl=nvim
    _X_flag=""
elif command_on_path vim; then
    _vi_impl=vim
    _X_flag="-X"
fi
if [ -n "${_vi_impl:=""}" ]; then
    alias vi="${_vi_impl} ${_X_flag} -u NONE +'set nocp bg=dark'"
    alias view="${_vi_impl} ${_X_flag} -Ru NONE +'set nocp bg=dark'"
fi
unset __abs_path

# Try to use a Vim with X compiled in (on Fedora/RedHat that is installed at
# `vimx` instead of the non-X-enabled `vim`), but disable X forwarding with
# Vim by default if we're connecting remotely, since it slows down Vim startup.
if [ -f /etc/fedora-release ] && command_on_path vimx; then
    _vim="command vimx"
else
    _vim="command vim"
fi
# Expand variables when defined, not when used.
# shellcheck disable=SC2139
if test -n "${SSH_CONNECTION:-}"; then
    alias vim="$_vim -X"
    alias vimx="$_vim"
else
    alias vim="$_vim"
    alias vimx="$_vim"
fi
unset _vim

# Run emacsclient in the background. Run the command using `eval` so that the
# "$@" variable is expanded in the output of `jobs`.
function ec {
    cmd="command $(printf '%q' "${EMACSCLIENT:-emacsclient}") -n"
    while [ -n "$1" ]; do
        cmd="$cmd $(printf ' %q' "$1")"
        shift
    done
    eval "$cmd"
}

# Connect to Vim server to edit file if present, else start server.
vc () {
    local VIM_SERVERNAME=${VIM_SERVERNAME:-VIM}
    local remote_cmd="--remote-tab"
    local args=""
    while [ -n "${1:-}" ]; do
        if [[ $1 =~ --?no(|[-_])tab ]]; then
            remote_cmd="--remote"
        else
            args="$args $(printf ' %q' "$1")"
        fi
        shift
    done
    local cmd="command vim --servername $(printf '%q' "${VIM_SERVERNAME}") ${remote_cmd}"
    eval "$cmd $args"  # Will fork if server exists, otherwise don't want to
}

# Start dummy X server in background -- particularly for Vim, whose server mode
# requires an X server to run but doesn't require windowing.
launch_dummy_X () {
    DUMMY_X_DISPLAY="${1:-}"
    test -n "${1:-}" || return 1
    # Command in startx must be an absolute path to an executable
    if [[ -x /opt/X11/bin/Xvfb ]]; then
        XVFB=${XVFB:-/opt/X11/bin/Xvfb}
    else
        XVFB=${XVFB:-/usr/bin/Xvfb}
    fi
    # Only spawn if server isn't running
    if ! [[ -S /tmp/.X11-unix/"X${DUMMY_X_DISPLAY#*:}" ]]; then
        ( cd /; "$XVFB" "${DUMMY_X_DISPLAY:-:50}" \
            -screen 0 1024x768x24 >/dev/null 2>&1 & disown )
    fi
}

# Override vc if connecting via SSH so that Vim connects by default to a Vim
# server running on a dummy X display $DUMMY_X_DISPLAY (the original behavior
# can be obtained using the `vcr` command.
if [[ -z "${DISPLAY:-}" ]] || [[ -n "${SSH_CONNECTION:-}" ]]; then
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
alias e="\$VISUAL"  # Escape `$` to not expand until used.
alias edit="\$VISUAL"  # Escape `$` to not expand until used.

# Functions to make use of the directory stack easier
# Go backwards in stack
b ()
{
    if [ ! -n "${1:-}" ]; then
        pushd +1
    else
        pushd +"$1"
    fi
}

# Go forwards in stack
f ()
{
    if [ ! -n "${1:-}" ]; then
        pushd -0
    else
        pushd -"$(( "$1" - 1 ))"
    fi
}

alias d="dirs"

# Add directories to the stack when changing directory
cd ()
{
    if [ ! -n "${1:-}" ]; then
        pushd "$HOME" > /dev/null
    elif [ "${1:-}" = '-' ]; then
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
__man_impl () {
    $__MOSTLIKE_TERM_CONFIG command man \"\$@\" \
        || (help \"\$@\" &>/dev/null && help \"\$@\" | less)
}
"
alias man=__man_impl
# Expand `__MOSTLIKE_TERM_CONFIG` when defined, not when used.
# shellcheck disable=SC2139
alias perldoc="$__MOSTLIKE_TERM_CONFIG perldoc"
unset __MOSTLIKE_TERM_CONFIG


# Safetly/convenience aliases for cp, mv, rm
__cp_impl () {
    if [ $# -eq 1 ]; then
        command cp -i "$1" .
    else
        command cp -i "$@"
    fi
}
alias cp=__cp_impl
__mv_impl () {
    if [ $# -eq 1 ]; then
        command mv -i "$1" .
    else
        command mv -i "$@"
    fi
}
alias mv=__mv_impl
# Alias to `rm -I` for GNU coreutils rm.
alias rm="rm -i"
if rm --version &>/dev/null; then
    alias rm="rm -I"
fi

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
function clean {
    (
        shopt -u failglob; shopt -s nullglob
        rm -f -- \#* *~ .*~ *.bak .*.bak  *.tmp .*.tmp core a.out
    )
}
alias rmtree='rm -r'

# Some useful aliases.
alias h='history'
alias o="xdg-open"
alias pu="pushd"
alias po="popd"
alias screen="/usr/bin/screen"
alias byobu="byobu -S byobu"
alias tcp-listeners="lsof -P -iTCP -sTCP:LISTEN"
command_on_path ack-grep && alias ack=ack-grep
command_on_path ag && alias ag='ag --pager=less'
command_on_path xdg-open && alias open="xdg-open"

# Wake-on-LAN
laplace_wakeonlan () {
    wakeonlan 00:15:F2:D2:23:BA
        wakeonlan 00:15:F2:D2:1F:D2
}

# rlwrap
alias bc="rlwrap bc"
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
    session="${1:-}"
    for client in $(tmux list-clients -t "$session" | cut -f 1 -d :); do
        tmux switch-client -c "$client" -t "$tmp"
    done

    # attach to the target session
    tmux attach -t "$session"
}

# Update dotfiles from Git upstream and install any changes
alias dotfiles-update='make -C ~/.dotfiles update'

# I like the Perl version of rename on Linux
command_on_path prename && alias rename=prename
command_on_path perl-rename && alias rename=perl-rename

# Always use unified diff, and use colors if possible
alias diff='diff -u'
command_on_path colordiff && alias diff='colordiff -u'

# Manage dotfiles in $HOME as a Git repo with its $GIT_DIR placed elsewhere.
alias config='git --git-dir="$HOME/.dotfiles-git-dir"'

# Update local configs
git_bounce () {
    (
        set -e -o pipefail
        # Parse commit references *before* changing branches, so the
        # cherry-pick onto master below selects the right references.
        if (( $# > 0 )); then
            local revs=( $(git rev-parse "$@") )
        fi
        git checkout master
        git pull
        (( $# > 0 )) && git cherry-pick "${revs[@]}"
        git push --force-with-lease
        git checkout -
        git rebase master
        git push --force-with-lease
    )
}
# Declares `config_bounce`
eval "$(declare -f git_bounce | sed -e 's/git/config/g')"

git-cd () {
  cd "$(git rev-parse --show-toplevel)/${1:-}"
}
alias gitcd=git-cd

# MacOS aliases
if [ $(uname) = "Darwin" ]; then
    alias vlc="/Applications/VLC.app/Contents/MacOS/VLC"
    alias gawk="rlwrap gawk"
    alias preview='open -a Preview'
fi
source_if_exists /opt/local/share/bash-completion/bash_completion
source_if_exists /opt/local/share/git/contrib/completion/git-completion.bash
source_if_exists ~/.iterm2_shell_integration.bash

function cheat() {
    curl https://cht.sh/$1
}

if [ $(uname -s) = 'Darwin' ]; then
    alias locate='echo "Use \`mdfind -name\` instead"; false'
fi

# Force dbxcli-refresh if necessary before running dbxcli
dbxcli () {
    command dbxcli-refresh
    command dbxcli "$@"
}

alias mail="ec -u -e '(call-interactively (quote rmail))'"

# Commands to use fzf to select and open editors based on the output of rg.
# tab opens the file without closing fzf; enter opens the file and closes fzf.
#
# Use `execute` here - I used to use `execute-silent`, but that will prevent
# keystrokes being drawn correctly with fzf 0.57 - it used to work with fzf
# 0.44, but no longer.
#
# If I don't want the selected line to appear when pressing Enter, I could use
# `become` instead of `execute` only for `enter` (not for `tab`). However,
# for now I prefer seeing what I selected.
rg-code () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); code --goto "$1:$2:$3" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
rg-vim () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); vim -c "$2" -c "norm 0" -c "norm $(( $3 - 1 ))l" "$1" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
rg-gvim () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); "$(if [ "$(uname)" = "Darwin" ]; then echo mvim; else echo gvim; fi)" -c "$2" -c "norm 0" -c "norm $(( $3 - 1 ))l" "$1" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
rg-ec () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); emacsclient -n "$(printf "\\x2b")$2:$3" "$1" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-code () {
    local fzf_cmd='execute(code {} </dev/tty >/dev/tty)'
    fd --color always "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-vim () {
    local fzf_cmd='execute(vim {} </dev/tty >/dev/tty)'
    fd --color always "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-gvim () {
    local fzf_cmd='execute("$(if [ "$(uname)" = "Darwin" ]; then echo mvim; else echo gvim; fi)" {} </dev/tty >/dev/tty)'
    fd --color always "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-ec () {
    local fzf_cmd='execute(emacsclient -n {} </dev/tty >/dev/tty)'
    fd --color always "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}

rga-fzf() {
    RG_PREFIX="rga --files-with-matches"
    local file
    file="$(
        FZF_DEFAULT_COMMAND="$RG_PREFIX '$1'" \
            fzf --sort --preview="[[ ! -z {} ]] && rga --pretty --context 5 {q} {}" \
                --phony -q "$1" \
                --bind "change:reload:$RG_PREFIX {q}" \
                --preview-window="70%:wrap"
    )" &&
    echo "opening $file" &&
    "$(command_on_path xdg-open && echo xdg-open || echo open)" "$file"
}
rga-fzf-ocr() {
    RG_PREFIX="rga --files-with-matches --rga-adapters=+pdfpages,tesseract"
    local file
    file="$(
        FZF_DEFAULT_COMMAND="$RG_PREFIX '$1'" \
            fzf --sort --preview="[[ ! -z {} ]] && rga --pretty --context 5 {q} {}" \
                --phony -q "$1" \
                --bind "change:reload:$RG_PREFIX {q}" \
                --preview-window="70%:wrap"
    )" &&
    echo "opening $file" &&
    "$(command_on_path xdg-open && echo xdg-open || echo open)" "$file"
}
