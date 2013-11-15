# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# TMUX
if hash tmux 2>/dev/null; then
    # If not inside a tmux session, and if no session is started, start
    # a new session -- but not if we're attached to the console.
    if test -z "$TMUX"; then
       case "$TERM" in
       cons*|linux*) ;;
       *)            (tmux attach || tmux new-session) ;;
       esac
    fi
fi

# Set umask to exclude group and other write permissions
umask 022

# Get proper SSH agent
. "$HOME/bin/find-ssh-agent"

# don't put duplicate lines or lines beginning with spaces in the history
export HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Terminal setup
# If in GNOME Terminal, set the appropriate TERM
if [ "$COLORTERM" = "gnome-terminal" ]; then
    export TERM="gnome-256color"
fi
# Handle screen pecularities
if [ -n "$STY" ]; then
    # byobu likes to set SSH_AUTH_SOCK for some reason. Bad!
    . "$HOME/bin/find-ssh-agent"
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
        TPUT=/usr/bin/tput
        tput() { TERM=ansi "$TPUT" "$@"; }
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

    # bright colors
    local BR="\[\033[0;91m\]"
    local BR="\[\033[0;91m\]"
    local BG="\[\033[0;92m\]"
    local BY="\[\033[0;93m\]"
    local BB="\[\033[0;94m\]"
    local BM="\[\033[0;95m\]"
    local BC="\[\033[0;96m\]"
    local BW="\[\033[0;97m\]"

    # background colors
    local BGK="\[$(tput setab 0)\]"
    local BGR="\[$(tput setab 1)\]"
    local BGG="\[$(tput setab 2)\]"
    local BGY="\[$(tput setab 3)\]"
    local BGB="\[$(tput setab 4)\]"
    local BGM="\[$(tput setab 5)\]"
    local BGC="\[$(tput setab 6)\]"
    local BGW="\[$(tput setab 7)\]"

    # bright background colors
    local BBGR="\[\033[0;101m\]"
    local BBGR="\[\033[0;101m\]"
    local BBGG="\[\033[0;102m\]"
    local BBGY="\[\033[0;103m\]"
    local BBGB="\[\033[0;104m\]"
    local BBGM="\[\033[0;105m\]"
    local BBGC="\[\033[0;106m\]"
    local BBGW="\[\033[0;107m\]"

    local BD="\[$(tput bold)\]" # bold
    local UL="\[$(tput smul)\]" # underline

    # reset terminal to normal text
    local RS="\[$(tput sgr0)\]"

    case $TERM in
    xterm*|rxvt*|screen*|putty*)
        if [ $EUID = 0 ]; then
            PS1="${BR}[${RS}\\u${BR}@${RS}\\h${BR}]${RS} ${BR}${UL}\\w${RS}\\n${R}\\D{%F %k:%M:%S} \\! \$${RS} "
            PS2="${R}…${RS} "
        else
            PS1="${BB}[${RS}\\u${BB}@${RS}\\h${BB}]${RS} ${BC}${UL}\\w${RS}\\n${C}\\D{%F %k:%M:%S} \\! \$${RS} "
            PS2="${R}…${RS} "
        fi
        ;;
    dumb)
        PS1='\u@\h:\w\$ '
        PS2='… '
        ;;
    *)
        if [ $EUID = 0 ]; then
            PS1="${R}[${RS}\\u${R}@${RS}\\h${R}]${RS} ${BD}${R}\\w${RS}\\n${R}\\D{%F %k:%M:%S} \\! \$${RS} "
            PS2="${R}…${RS} "
        else
            PS1="${B}[${RS}\\u${B}@${RS}\\h${B}]${RS} ${BD}${C}\\w${RS}\\n${C}\\D{%F %k:%M:%S} \\! \$${RS} "
            PS2="${R}…${RS} "
        fi
        ;;
    esac
}

bash_prompt_setup
unset bash_prompt_setup

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|screen)
    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/$HOME/~}\007"'
    ;;
*)
    ;;
esac

# Replace the edit-and-execute-command bindings, which use VISUAL and EDITOR, with
# a custom function after
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
        vim -eXu NONE --cmd 'set t_ti= t_te=' $TMPF && READLINE_LINE=$(< $TMPF)
        rm -f $TMPF
        READLINE_POINT=$p # or p or ${#READLINE_LINE} or ...
}
bind -m vi -x '"v":__bind_edit_in_editor'
bind -m emacs -x '"\C-x\C-e":__bind_edit_in_editor'

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

