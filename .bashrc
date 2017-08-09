# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "${PS1:-}" ] && return


[ -f "$HOME/.common.sh" ] && . "$HOME/.common.sh"

# Set umask to exclude group and other write permissions
umask 022

# Set up tmux attach actions
[ -f "$HOME/.bash_tmux_reattach" ] && . "$HOME/.bash_tmux_reattach"

# # Import ssh-agent settings
# [ -f "$(command -v find-ssh-agent)" ] && . find-ssh-agent

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# Enable extended glob patterns
shopt -s extglob

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Terminal setup
precmd_functions+=(precmd_prompt_exit_status)
# Disable flow control
stty stop undef
# If in GNOME Terminal, set the appropriate TERM
if [ "${COLORTERM:-}" = "gnome-terminal" ]; then
    export TERM="gnome-256color"
fi
# Handle screen pecularities
if [ -n "$STY" ]; then
    # byobu likes to set SSH_AUTH_SOCK for some reason. Bad!
    [ -f "$HOME/bin/find-ssh-agent" ] && . "$HOME/bin/find-ssh-agent"
fi
case "$TERM" in
putty*)
    # Get arrow keys to work correctly: put terminal in application keys mode
    # and reassign inputrc
    setterm -appcursorkeys on
    export INPUTRC="$HOME/.inputrc-putty"
    ;;
esac

# set a fancy prompt (non-color, unless we know we "want" color)
bash_prompt_setup() {
    # make tput act as if on an ANSI terminal if the TERM environment
    # variable specifies an unavailable TERM (we want to keep TERM since
    # we're usually gonna SSH to a computer with the right TERM anyway,
    # and ANSI is a lowest-common-denominator TERM)
    if ! tput longname &> /dev/null; then
        tput() { TERM=ansi command tput "$@"; }
    fi

    # normal colors
    local K="\[$(tput setaf 0)\]"    # black
    local R="\[$(tput setaf 1)\]"    # red
    local G="\[$(tput setaf 2)\]"    # green
    local Y="\[$(tput setaf 3)\]"    # yellow
    local B="\[$(tput setaf 4)\]"    # blue
    local M="\[$(tput setaf 5)\]"    # magenta
    local C="\[$(tput setaf 6)\]"    # cyan
    local W="\[$(tput setaf 7)\]"    # white

    # background colors
    local BGK="\[$(tput setab 0)\]"
    local BGR="\[$(tput setab 1)\]"
    local BGG="\[$(tput setab 2)\]"
    local BGY="\[$(tput setab 3)\]"
    local BGB="\[$(tput setab 4)\]"
    local BGM="\[$(tput setab 5)\]"
    local BGC="\[$(tput setab 6)\]"
    local BGW="\[$(tput setab 7)\]"

    case $TERM in
    # Assume these terminals support at least 16 colors, since TERM is often
    # set to these even if the terminal supports more colors.
    xterm|rxvt|screen|putty)
        ;;&
    # Explicitly enable for all terminals with >8 colors
    *-[0-9]+([0-9])color?(-*))
        # bright colors
        local BK="\[\033[0;90m\]"
        local BR="\[\033[0;91m\]"
        local BG="\[\033[0;92m\]"
        local BY="\[\033[0;93m\]"
        local BB="\[\033[0;94m\]"
        local BM="\[\033[0;95m\]"
        local BC="\[\033[0;96m\]"
        local BW="\[\033[0;97m\]"

        # bright background colors
        local BBGK="\[\033[0;100m\]"
        local BBGR="\[\033[0;101m\]"
        local BBGG="\[\033[0;102m\]"
        local BBGY="\[\033[0;103m\]"
        local BBGB="\[\033[0;104m\]"
        local BBGM="\[\033[0;105m\]"
        local BBGC="\[\033[0;106m\]"
        local BBGW="\[\033[0;107m\]"
        ;;

    # Simulate bright colors with normal if bright colors are not supported
    *)
        local BK="${K}"
        local BR="${R}"
        local BG="${G}"
        local BY="${Y}"
        local BB="${B}"
        local BM="${M}"
        local BC="${C}"
        local BW="${W}"

        local BBGK="${BGK}"
        local BBGR="${BGR}"
        local BBGG="${BGG}"
        local BBGY="${BGY}"
        local BBGB="${BGB}"
        local BBGM="${BGM}"
        local BBGC="${BGC}"
        local BBGW="${BGW}"
        ;;

    esac

    local BD="\[$(tput bold)\]" # bold
    local UL="\[$(tput smul)\]" # underline

    # reset terminal to normal text
    local RS="\[$(tput sgr0)\]"

    ##################
    # Prompts themselves

    local __pwd_escaped='$(__pwd=${PWD#$HOME};
        if [ "$__pwd" = "$PWD" ]; then
            __pwd=$(printf "%q" "${__pwd}");
        else
            __pwd=${__pwd%/};
            if [ -n "$__pwd" ]; then
                __pwd=${__pwd#/};
                __pwd=$(printf "~/%q" "${__pwd}");
            else
                __pwd="~";
            fi;
        fi;
        printf "%s" "${__pwd}";)'

    unset PS1 PS2

    if [ "$TERM" = "dumb" ]; then
        PS1='\u@\h:'"${__pwd_escaped}"'\$ '
        PS2='… '
        return 0
    fi

    # If this is an xterm set the title to user@host:dir
    case "$TERM" in
    xterm*|rxvt*|screen*|putty*|*-256color)
        precmd_xterm_title () {
            printf "\033]0;%s: %s\007" "${USER}@${HOSTNAME}" "${__pwd_escaped}"
        }
        precmd_functions+=(precmd_xterm_title)
        ;;
    esac

    _my_prompt_command() {
        # Record exit status of executed command.
        precmd_prompt_exit_status () {
            # $__bp_last_ret_value is set by bash-preexec to be the return value of the
            # command executed at the prompt.
            __PROMPT_EXIT_STATUS=$__bp_last_ret_value
        }

        # Set color based on the exit status of the lsat command.
        local exit_status_cmd='$(test $__PROMPT_EXIT_STATUS -eq 0 && printf %s "'${G}'" || printf %s "'${BR}'")'
        PS1="${1}[${2}\\u${3}@${4}\\h${5}]${6} ${7}${__pwd_escaped}${8}"$'\n'
        # Second line of prompt - start with `:` and end with `;` to allow
        # copying commands straight from the shell and re-executing them
        # without having to edit them. The `$`/`#` prompt is preceded by
        # a backslash to prevent any interpretation by the shell - this
        # requires 3 backslashes before `$` in `PS1`, since Bash interprets
        # backslashes as escapes when evaluating `PS1`.
        PS1="${PS1}${9}: ${10}\\D{%F %k:%M:%S} \! ${exit_status_cmd}"'\\\$'";${11} "
        PS2="${12}…${13} "
    }

    if [ $EUID = 0 ]; then
        _my_prompt_command ${BR} ${RS} ${BR} ${RS} ${BR} ${RS} ${BR}${UL} ${RS} \
            ${R} "" ${RS} \
            ${R} ${RS}
    else
        _my_prompt_command ${BB} ${RS} ${BB} ${RS} ${BB} ${RS} ${BC}${UL} ${RS} \
            ${C} "" ${RS} \
            ${R} ${RS}
    fi
    unset _my_prompt_command
}

bash_prompt_setup
unset bash_prompt_setup

# Replace the edit-and-execute-command bindings, which use VISUAL and EDITOR,
# with a custom function after
# <http://gnu-bash.2382.n7.nabble.com/edit-and-execute-command-is-appropriately-named-weird-td3617.html> (retrieved 2013-01-14).
__bind_edit_in_editor()
{
        typeset p
        local TMPF=/tmp/readline-buffer.$$.$RANDOM

        p=${READLINE_POINT}
        rm -f $TMPF
        tput bold
        printf "%s\n" "$READLINE_LINE" | tee "$TMPF"
        tput sgr0
        # ${FCEDIT} args must be double-quoted because it uses `eval`
        ${FCEDIT} -E \
            -c "'source ~/.vim/plugged/vim-bracketed-paste/plugin/bracketed-paste.vim'" \
            "$(printf '%q' "$TMPF")" \
            && READLINE_LINE=$(< "$TMPF")
        rm -f $TMPF
        READLINE_POINT=$p # or p or ${#READLINE_LINE} or ...
}
bind -m vi -x '"v":__bind_edit_in_editor'
bind -m emacs -x '"\C-x\C-e":__bind_edit_in_editor'

# Merge home directory correctly into xrdb
if [ -n "${DISPLAY:-}" ] && [ -z "${SSH_CONNECTION:-}" ] && command_on_path xrdb; then
    echo "URxvt.perl-lib: $HOME/.urxvt/ext/urxvt-perls/" | xrdb -merge
fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# History control
# no duplicate entries, and ignore entries starting with space
HISTCONTROL=ignorespace:erasedups
# Don't truncate history
HISTSIZE=-1; unset HISTFILESIZE
# Store multi-line command lines correctly
shopt -s cmdhist lithist
# Allow editing history lines on failure or from history expansion
shopt -s histreedit histverify

# Save and reload the history after each command finishes
shopt -s histappend                      # append to history, don't overwrite
precmd_history_append () { history -a; }
precmd_functions+=(precmd_history_append)

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Modify __fzf_history__ to remove duplicate commands from the history fed into
# `fzf`.
__new_fzf_history__() {
    history () {
        builtin history |
        awk '{
            cmd = $0; sub(/^ *[0-9]+  /, "", cmd);
            if (!seen[cmd]) { print $0; seen[cmd] = 1; }
        }'
    }
    __orig_fzf_history__ "$@"
}

replace_fzf_history() {
    local orig_def=$(declare -f __fzf_history__ \
        | sed 's/__fzf_history__/__orig_fzf_history__/g')
    eval "$orig_def"
    local new_def=$(declare -f __new_fzf_history__ \
        | sed 's/__new_fzf_history__/__fzf_history__/g')
    eval "$new_def"
}

replace_fzf_history

# LOCAL SETTINGS
if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
