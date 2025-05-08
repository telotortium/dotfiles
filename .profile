# -*- mode: sh -*-
# shellcheck shell=dash
# shellcheck disable=SC1090,SC1091
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# Include guard
if [ -n "${__MY_PROFILE_SOURCED:-}" ]; then
    return
fi
__MY_PROFILE_SOURCED=1

if [ -f ~/.common.sh ]; then
    . ~/.common.sh
fi

# Set shell prefix and package manager
__shell_path=$(command -v "$SHELL")
shell_prefix="${__shell_path%/bin/*}"
unset __shell_path
pkg_manager=""
if [ -f "${shell_prefix}/bin/brew" ]; then
    pkg_manager="homebrew"
elif [ -f "${shell_prefix}/bin/port" ]; then
    pkg_manager="macports"
elif [ -f "${shell_prefix}/bin/nix" ]; then
    pkg_manager="nix"
elif [ -f "${shell_prefix}/bin/apt" ]; then
    pkg_manager="apt"
elif [ -f "${shell_prefix}/bin/yum" ]; then
    pkg_manager="yum"
fi

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
if [ "$pkg_manager" = "macports" ]; then
    if ! ( echo "$PATH" | grep -q "/usr/local/bin:${shell_prefix}/bin" ); then
        # ${variable//search/replace} doesn't work in Posix shell.
        # shellcheck disable=SC2001
        PATH="$(echo "$PATH" | sed "s!/usr/local/bin!/usr/local/bin:${shell_prefix}/bin!g")"
    fi
    if ! ( echo "$PATH" | grep -q "/usr/local/sbin:${shell_prefix}/sbin" ); then
        # ${variable//search/replace} doesn't work in Posix shell.
        # shellcheck disable=SC2001
        PATH="$(echo "$PATH" | sed "s!/usr/local/sbin!/usr/local/sbin:${shell_prefix}/sbin!g")"
    fi
    pathvarmunge MANPATH "$shell_prefix/share/man"
    pathvarmunge INFOPATH "$shell_prefix/share/info"

    # Fix spurious "Warning: The macOS 11.1 SDK does not appear to be installed."
    # from Macports on 11.1
    export SYSTEM_VERSION_COMPAT=0
fi

# Homebrew variables
if [ "$pkg_manager" = "homebrew" ]; then
    pathvarmunge PATH "$shell_prefix/bin"
    # Ensure MANPATH is in front.
    MANPATH="$shell_prefix/share/man:$MANPATH"
    pathvarmunge MANPATH "$shell_prefix/share/man"
    pathvarmunge INFOPATH "$shell_prefix/share/info"
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
#
# If running in VSCode-like editors, detect the specific program we're running
# under, falling back to `code` for Visual Studio Code.
#
# Otherwise, if `gvim` is available, use it.
#
# Otherwise, use `vim`.
if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    if  [ "${__CFBundleIdentifier:-}" = "com.exafunction.windsurf" ]; then
        export EDITOR="windsurf --wait"
    elif [ -n "${CURSOR_TRACE_ID:-}" ]; then
        export EDITOR="cursor --wait"
    else
        export EDITOR="code --wait"
    fi
    export ALTERNATE_EDITOR=vim
    export GIT_EDITOR=vim
elif command_on_path gvim; then
    # Make sure that `gvim` doesn't fork, since a lot of programs that use
    # `$EDITOR` wait for it to exit before proceeding.
    # `+:` ensures that other arguments are read as file names, not commands.
    export EDITOR="gvim --nofork --remote-tab-wait-silent +:"
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
    export FCEDIT="vim -E --noplugin -u ~/.vim/fc.vim"
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

# ASDF init (v0.16+)
if command_on_path asdf; then
    export ASDF_DATA_DIR="$HOME/.asdf"
    pathvarmunge PATH "$ASDF_DATA_DIR/shims"
fi

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
