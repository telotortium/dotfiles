# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

[ -f "$HOME/.common.sh" ] && . "$HOME/.common.sh"

# path_prepend|path_append current_value to_add
# Add directories to a path environment variable without leaving empty
# elements, which are equivalent to the current directory.
path_prepend () {
    echo "${2}$(test -n "$1" && echo :"$1")"
}
path_append () {
    echo "$(test -n "$1" && echo "$1":)${2}"
}

# Evaluate system PATH on OS X
if [ -x /usr/libexec/path_helper ]; then
    eval `/usr/libexec/path_helper -s`
fi

# User specific environment and startup programs
export PATH="$(path_prepend "$PATH" \
    "$HOME/bin:$HOME/winbin:$HOME/.local/bin:$HOME/.cabal/bin")"

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

export TEXMFHOME=$HOME/.texmf

# Import ssh-agent settings
[ -f "$(command -v find-ssh-agent)" ] && . find-ssh-agent

# Python initialization
export PYTHONSTARTUP=$HOME/.pythonstartup
python_version="$(python --version 2>&1 | sed 's/^Python \([0-9]\)\..*/\1/')"
case "$python_version" in
2)
    d="$HOME/local/python/python2"
    test -d "$d" && export PYTHONPATH="$(path_prepend "$PYTHONPATH" "$d")"
    ;;
3)
    d="$HOME/local/python/python3"
    test -d "$d" && export PYTHONPATH="$(path_prepend "$PYTHONPATH" "$d")"
    ;;
esac
unset d python_version

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
export GOMAXPROCS=$(__ncpu)
unset __ncpu
export GOPATH="$HOME/Documents/code/go"
export PATH="$(path_prepend "$PATH" "$GOPATH/bin")"

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

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi

unset path_prepend
unset path_append
