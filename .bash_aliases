# -*- mode: sh -*-

# Include guard
if [ -n "${__MY_BASH_ALIASES_SOURCED:-}" ]; then
    return
fi
__MY_BASH_ALIASES_SOURCED=1

# Page following command with color - works with most GNU tools and others
# like them.
cless () {
    args=()
    prog="$1"
    shift;
    case "$(basename "$prog")" in
    jq)
        args+=( -C ) ;;
    *)
        args+=( --color=always ) ;;
    esac
    "$prog" "${args[@]}" "$@" | less -R
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

# General alias for launching an editor based on the value of $VISUAL, using Bash builtins for lowercase conversion
function e {
    # If VISUAL is not set, default to launching emacsagent
    if [ -z "$VISUAL" ]; then
         local visual_bin="emacsagent"
    else
         # Extract the first word from $VISUAL
         local visual_bin="${VISUAL%% *}"
    fi
    # Use Bash parameter expansion to convert to lowercase (requires Bash 4+)
    local lower_visual="${visual_bin,,}"
    local cmd=""
    case "$lower_visual" in
    *gvim|*mvim|*macvim)
        # For gvim, mvim, or macvim, launch without forking and open in remote tab mode
        cmd="$visual_bin --remote-tab-silent +:" ;;
    *code|*cursor|*windsurf)
        cmd="$visual_bin" ;;
    *)
        # Fallback: use emacsagent (or emacsclient) in non-blocking mode
        cmd="${EMACSCLIENT:-emacsclient} -n" ;;
    esac

    # Append any arguments passed to the alias, properly quoted
    for arg in "$@"; do
         cmd="command $cmd $(printf '%q' "$arg")"
    done
    eval "$cmd"
}
function edit {
    $EDTIOR "$@"
}
function vscode_cmd_name {
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]] && [[ -n "${CURSOR_TRACE_ID:-}" ]]; then
        echo "cursor"
    elif [[ "${TERM_PROGRAM:-}" == "vscode" ]] && [[ "${__CFBundleIdentifier:-}" == com.exafunction.windsurf ]]; then
        echo "windsurf"
    else
        echo "code"
    fi
}
function code {
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]] && [[ "$(vscode_cmd_name)" != code ]]; then
        # Prompt to make sure we want to open in Code when running under Cursor
        # or Windsurf.
        read -p "Are you sure you want to open this file in Code? (y/n) " -n 1 -r
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    if [[ $# -eq 1 ]] && [[ -d "$1" ]]; then
        # Prompt to make sure we want to open directory.
        read -p "Are you sure you want to open this directory in Code? (y/n) " -n 1 -r
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    command code --reuse-window "$@"
}
function cursor {
    # shellcheck disable=SC2237
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]] && [[ "$(vscode_cmd_name)" != cursor ]]; then
        # Prompt to make sure we want to open in Code when running under Cursor.
        read -p "Are you sure you want to open this file in Cursor? (y/n) " -n 1 -r
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    if [[ $# -eq 1 ]] && [[ -d "$1" ]]; then
        # Prompt to make sure we want to open directory.
        read -p "Are you sure you want to open this directory in Cursor? (y/n) " -n 1 -r
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    command cursor --reuse-window "$@"
}
function windsurf {
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]] && [[ "$(vscode_cmd_name)" != windsurf ]]; then
        # Prompt to make sure we want to open in Code when running under Windsurf.
        read -p "Are you sure you want to open this file in Windsurf? (y/n) " -n 1 -r
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    if [[ $# -eq 1 ]] && [[ -d "$1" ]]; then
        # Prompt to make sure we want to open directory.
        read -p "Are you sure you want to open this directory in Windsurf? (y/n) " -n 1 -r
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    command windsurf --reuse-window "$@"
}
alias ec="VISUAL=emacsclient e"


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
source ~/bin/git-rebase-base  # Provide git-rebase-base


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
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); '"$(vscode_cmd_name)"' --reuse-window --goto "$1:$2:$3" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
rg-vim () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); vim -c "$2" -c "norm 0" -c "norm $(( $3 - 1 ))l" "$1" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
rg-gvim () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); "$(if [ "$(uname)" = "Darwin" ]; then echo mvim; else echo gvim; fi)" -c "$2" -c "norm 0" -c "norm $(( $3 - 1 ))l" --nofork --remote-tab-wait-silent +: "$1" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
rg-ec () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); emacsclient -n "$(printf "\\x2b")$2:$3" "$1" </dev/tty >/dev/tty)'
    rg --smart-case --vimgrep --color ansi "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-code () {
    local fzf_cmd='execute(IFS=$(printf "\\n") set $(echo {} | sed -E -e "s/^(.*):([0-9][0-9]*):([0-9][0-9]*):.*/\\1\\n\\2\\n\\3/"); '"$(vscode_cmd_name)"' --reuse-window {} </dev/tty >/dev/tty)'
    fd --color always "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-vim () {
    local fzf_cmd='execute(vim {} </dev/tty >/dev/tty)'
    fd --color always "$@" \
        | fzf --tmux --ansi --bind="tab:${fzf_cmd},enter:${fzf_cmd}+accept"
}
fd-gvim () {
    local fzf_cmd='execute("$(if [ "$(uname)" = "Darwin" ]; then echo mvim; else echo gvim; fi)" --nofork --remote-tab-wait-silent +: {} </dev/tty >/dev/tty)'
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

# q and qv from https://github.com/davidgasquez/dotfiles/blob/bb9df4a369dbaef95ca0c35642de491c7dd41269/shell/zshrc#L50-L99
# via https://simonwillison.net/2024/Dec/19/q-and-qv-zsh-functions/.
function q() (
    set -eu -o pipefail
    local usage="USAGE: q ARTICLE_URL QUESTION"
    local url="${1?${usage}}"
    local question="${2?${usage}}"

    # Fetch the URL content through Jina
    local content=$(curl -s "https://r.jina.ai/$url")

    # Check if the content was retrieved successfully
    if [ -z "$content" ]; then
        echo "Failed to retrieve content from the URL."
        return 1
    fi

    system="
    You are a helpful assistant that can answer questions about the content.
    Reply concisely, in a few sentences.

    The content:
    ${content}
      "

    # Use llm with the fetched content as a system prompt
    llm prompt "$question" -s "$system"
)

function qv() (
    set -eu -o pipefail

    local usage="USAGE: qv VIDEO_URL QUESTION"
    local url="${1?${usage}}"
    local question="${2?${usage}}"

    # Fetch the URL content through Jina
    local subtitle_url=$(yt-dlp -q --skip-download --convert-subs srt --write-sub --sub-langs "en" --write-auto-sub --print "requested_subtitles.en.url" "$url")
    local content=$(curl -s "$subtitle_url" | sed '/^$/d' | grep -v '^[0-9]*$' | grep -v '\-->' | sed 's/<[^>]*>//g' | tr '\n' ' ')

    # Check if the content was retrieved successfully
    if [ -z "$content" ]; then
        echo "Failed to retrieve content from the URL."
        return 1
    fi

    system="
You are a helpful assistant that can answer questions about YouTube videos.
Reply concisely, in a few sentences.

The content:
${content}
"

    # Use llm with the fetched content as a system prompt
    llm prompt "$question" -s "$system"
)

# bwatch - like `watch` but has access to shell functions and aliases.
# [Made using ChatGPT]
# (https://chatgpt.com/share/e/67db4dd8-4364-800e-9391-01b954348d02)
bwatch() {
  local interval=2

  # Process options.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--interval)
        if [[ -n "$2" && "$2" != -* ]]; then
          interval="$2"
          shift 2
        else
          echo "Error: -n requires a numerical argument" >&2
          return 1
        fi
        ;;
      -h|--help)
        echo "Usage: bwatch [-n interval] command [args...]"
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    echo "Usage: bwatch [-n interval] command [args...]"
    return 1
  fi

  # Combine remaining arguments into a single command string.
  # This passes the command verbatim to eval.
  local cmd_str="$*"

  # Record the start time.
  local start_epoch
  start_epoch=$(date +%s)
  local start_time
  start_time=$(date '+%Y-%m-%d %H:%M:%S')

  # Main loop: clear the screen, show header, run the command in a subshell, then sleep.
  while true; do
    clear
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    local elapsed=$(( $(date +%s) - start_epoch ))
    echo "Every ${interval} seconds: $cmd_str"
    echo "Start: $start_time   Now: $now   Elapsed: ${elapsed} sec"
    echo "------------------------------------------------------------"
    # Run the command in a subshell so that it runs with your shell functions/aliases.
    ( eval "$cmd_str" )
    local exit_code=$?
    echo "------------------------------------------------------------"
    echo "Exit code: $exit_code"
    sleep "$interval"
  done
}

alias pn="pnpm"
pf() {
  if [ $# -lt 2 ]; then
    echo "Usage: pf <project> <command> [args...]"
    return 1
  fi
  project=$1; shift
  pnpm --filter="$project" "$@"
}
