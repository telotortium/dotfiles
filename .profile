# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile
#umask 022

# path_prepend|path_append current_value to_add
# Add directories to a path environment variable without leaving empty
# elements, which are equivalent to the current directory.
path_prepend () {
    echo "$2$(test -n "$1" && echo :"$1")"
}
path_append () {
    echo "$(test -n "$1" && echo "$1":)$2"
}

# User specific environment and startup programs
export PATH="$(path_prepend "$PATH" \
    $HOME/bin:$HOME/winbin:$HOME/local/bin:$HOME/.cabal/bin)"

if which gvim &> /dev/null; then
    export EDITOR=gvim
    export ALTERNATE_EDITOR=vim
elif which vim &> /dev/null; then
    export EDITOR=vim
    export ALTERNATE_EDITOR=vi
else
    export EDITOR=vi
fi

# Input method
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS="@im=ibus"
# Set MATLAB to use the starting directory specified by `userpath'.
export MATLAB_USE_USERPATH=1

export FCEDIT="vim -Xu NONE"
export PAGER=less
export ACK_PAGER_COLOR="less -R"
export LESS=X
export VISUAL=$EDITOR
export HISTIGNORE="&:ls:ls:mutt:[bf]g:exit:exec:exec *"

export TEXMFHOME=$HOME/.texmf

# Import ssh-agent settings
. $HOME/bin/find-ssh-agent

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

# Go path setup
export GOPATH="$(path_prepend "$GOPATH" "$HOME/Documents/code/go")"

# Perl local::lib
eval "$(perl -I$HOME/local/perl5 -Mlocal::lib)"

unset path_prepend
unset path_append
