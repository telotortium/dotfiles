# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

[ -f "$HOME/.common.sh" ] && . "$HOME/.common.sh"

# Evaluate system PATH on OS X
if [ -x /usr/libexec/path_helper ]; then
    eval "$(/usr/libexec/path_helper -s)"
fi

# User specific environment and startup programs
pathvarmunge PATH /usr/local/bin
pathvarmunge PATH "$HOME/.cabal/bin"
pathvarmunge PATH "$HOME/.local/bin"
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
export MANPAGER="$PAGER"
export LESS="XRI"
# Page scroll is often slow on the Linux console with higher resolution unless
# the -C option is passed.
[ "$TERM" = "linux" ] && export LESS="${LESS}C"

if command_on_path nvim; then
    export MANPAGER="nvim -u NONE -c 'syntax on'  -c 'filetype plugin indent on' -c 'set nocp ft=man' -"
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
pathvarmunge PATH "$HOME/.cargo/bin"

# Nix
pathvarmunge PATH "$HOME/.nix-profile/bin"

# Perl local::lib - don't try to load it if it isn't installed
if perl -Mlocal::lib -e1 2>/dev/null && [ -d "$HOME/local/perl5" ]; then
    eval "$(perl -I"$HOME/local/perl5" -Mlocal::lib)"
fi

# Set mosh escape key to be like SSH (requires recent version - introduced in
# github.com/keithw/mosh commit f960a8).
#
# Not expanding tilde is intentional --
# shellcheck disable=SC2088
export MOSH_ESCAPE_KEY='~'

# Emacs server - set default name of Emacs server (relies on server also running
# over TCP rather than local socket).
export EMACS_SERVER_FILE=~/.doom.d/doom.emacs.d/server/server

# MacPorts variables
if [ -f /opt/local/etc/macports/macports.conf ]; then
    pathvarmunge PATH /opt/local/sbin
    pathvarmunge PATH /opt/local/bin
    pathvarmunge MANPATH /opt/local/share/man

    # Fix spurious "Warning: The macOS 11.1 SDK does not appear to be installed."
    # from Macports on 11.1
    export SYSTEM_VERSION_COMPAT=0

    # MacPorts wants a DISPLAY variable set
    export DISPLAY=:0
fi

if [ -d "$HOME/misc/build/git-tools" ]; then
    pathvarmunge PATH "$HOME/misc/build/git-tools"
    pathvarmunge MANPATH "$HOME/misc/build/git-tools"
fi

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
