# -*- mode: sh -*-
# shellcheck shell=sh
# shellcheck disable=SC1090,SC1091
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

[ -f "$HOME/.common.sh" ] && . "$HOME/.common.sh"

# Evaluate system PATH on OS X
if [ -x /usr/libexec/path_helper ]; then
    # If MANPATH is not yet present in the environment, `path_helper` will not
    # print a value for MANPATH, so make sure it's present.
    MANPATH="${MANPATH:-}"; export MANPATH
    eval "$(/usr/libexec/path_helper -s)"
    # path_helper is leaving a trailing ":" on its variables, so remove it.
    PATH=${PATH%*:}
    MANPATH=${MANPATH%*:}
fi

# MacPorts variables
if [ -f /opt/local/etc/macports/macports.conf ]; then
    if ! ( echo "$PATH" | grep -q "/usr/local/bin:/opt/local/bin" ); then
        # ${variable//search/replace} doesn't work in Posix shell.
        # shellcheck disable=SC2001
        PATH="$(echo "$PATH" | sed 's!/usr/local/bin!/usr/local/bin:/opt/local/bin!g')"
    fi
    if ! ( echo "$PATH" | grep -q "/usr/local/sbin:/opt/local/sbin" ); then
        # ${variable//search/replace} doesn't work in Posix shell.
        # shellcheck disable=SC2001
        PATH="$(echo "$PATH" | sed 's!/usr/local/sbin!/usr/local/sbin:/opt/local/sbin!g')"
    fi
    pathvarmunge MANPATH /opt/local/share/man

    # Fix spurious "Warning: The macOS 11.1 SDK does not appear to be installed."
    # from Macports on 11.1
    export SYSTEM_VERSION_COMPAT=0
fi

# User specific environment and startup programs
pathvarmunge PATH /usr/local/bin
pathvarmunge MANPATH /usr/local/share/man
pathvarmunge PATH "$HOME/.cabal/bin"
pathvarmunge PATH "$HOME/.local/bin"
pathvarmunge PATH "$HOME/.fzf/bin"
pathvarmunge MANPATH "$HOME/.fzf/man"
pathvarmunge PATH "$HOME/winbin"
pathvarmunge PATH "$HOME/bin"

# Default editor
# Make sure that `gvim` doesn't fork, since a lot of programs that use
# `$EDITOR` wait for it to exit before proceeding.
if command_on_path gvim; then
    export EDITOR="gvim --nofork"
    export ALTERNATE_EDITOR=vim
elif command_on_path vim; then
    export EDITOR=vim
    export ALTERNATE_EDITOR=vi
else
    export EDITOR=vi
fi

# Set the COLORFGBG environment to force Vim to assume a dark terminal
# background.
export COLORFGBG=${COLORFGBG:-"7;0"}

# Input method
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS="@im=ibus"
# Set MATLAB to use the starting directory specified by `userpath'.
export MATLAB_USE_USERPATH=1

if command_on_path vim; then
    export FCEDIT="eval vim -Xu NONE \
        -c 'syntax on'  -c 'filetype plugin indent on' \
        -c 'let g:is_posix=1' -c 'set nocp filetype=sh' \
        "
else
    export FCEDIT="vi"
fi
export VISUAL="$EDITOR"
export HISTIGNORE="&:ls:ls:mutt:[bf]g:exit:exec:exec *"

export PAGER=less
# Take default LESS value from https://github.com/sharkdp/bat documentation.
# There it's documented that X is only needed for less versions before 530, so
# check the `less` version. Also add I because I like case-insensitive search
# by default.
export LESS="FRI"
if ! [ "$(less -V | head -n1 | sed -E 's/^less ([0-9]+).*/\1/')" -ge 530 ]
then
    LESS="${LESS}X"
fi
export MANPAGER="$PAGER"

if command_on_path bat; then
    export BAT_THEME="Monokai Extended"
    MANPAGER='sh -c "col -bx | bat --language=man --plain -"'
fi


# Page scroll is often slow on the Linux console with higher resolution unless
# the -C option is passed.
[ "$TERM" = "linux" ] && export LESS="${LESS}C"

if command_on_path nvimpager; then
    export MANPAGER="nvimpager"
fi

export TEXMFHOME=$HOME/.texmf

# Import ssh-agent settings
[ -f "$(command -v find-ssh-agent)" ] && . find-ssh-agent

# Python initialization
export PYTHONSTARTUP=$HOME/.pythonstartup

# Go initialization
__ncpu () {
    if command_on_path nproc; then
        nproc
        return
    fi
    case $(uname) in
    Darwin)
        /usr/sbin/sysctl -n hw.ncpu ;;
    # Fallback: 1 core
    *)
        echo 1 ;;
    esac
}
GOMAXPROCS=$(__ncpu); export GOMAXPROCS
unset __ncpu
GOPATH="$HOME/Documents/code/go"; export GOPATH
pathvarmunge PATH "$GOPATH/bin"

# Rust initialization
. "$HOME/.cargo/env"

# Nix
pathvarmunge PATH "$HOME/.nix-profile/bin"

# Perl local::lib - don't try to load it if it isn't installed
if perl -Mlocal::lib -e1 2>/dev/null && [ -d "$HOME/local/perl5" ]; then
    eval "$(perl -I"$HOME/local/perl5" -Mlocal::lib)"
fi

# Export MOSH_CONNECTION variable, which can be used by later code to determine
# if connection was made over Mosh.
if pstree -p $$ | grep -q '[m]osh-server'; then
    export MOSH_CONNECTION=1
else
    export MOSH_CONNECTION=
fi

# Set mosh escape key to be like SSH (requires recent version - introduced in
# github.com/keithw/mosh commit f960a8).
#
# Not expanding tilde is intentional --
# shellcheck disable=SC2088
export MOSH_ESCAPE_KEY='~'

# Emacs server - set default name of Emacs server (relies on server also running
# over TCP rather than local socket).
export EMACS_SERVER_FILE=~/doom.emacs.d/server/server

# Doom Emacs - set Git config to always use my personal name and email for
# repos managed by Straight.
if [ -f ~/.doom.d/.doomgitconfig ]; then
    export DOOMGITCONFIG=~/.doom.d/.doomgitconfig
fi

if [ -d "$HOME/misc/build/git-tools" ]; then
    pathvarmunge PATH "$HOME/misc/build/git-tools"
    pathvarmunge MANPATH "$HOME/misc/build/git-tools"
fi

# Visual Studio Code (VSCode)
VSCODE_BIN_DIR="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
if [ -d "${VSCODE_BIN_DIR}" ]; then
    pathvarmunge PATH "${VSCODE_BIN_DIR}"
fi

# ASDF init
if [ -f "/opt/local/share/asdf/asdf.sh" ]; then
    . "/opt/local/share/asdf/asdf.sh"
fi

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
