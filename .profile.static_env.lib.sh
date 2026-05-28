# -*- mode: sh -*-
# shellcheck shell=dash

_my_profile_apply_static_env() {
    # Set shell prefix and package manager
    __shell_path=$(command -v "${SHELL:-bash}")
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

    # Evaluate system PATH on macOS.
    if [ -x /usr/libexec/path_helper ]; then
        MANPATH="${MANPATH:-}"; export MANPATH
        eval "$(/usr/libexec/path_helper -s)"
        PATH=${PATH%:}
        MANPATH=${MANPATH%:}
    fi

    # MacPorts variables
    if [ "$pkg_manager" = "macports" ]; then
        case ":$PATH:" in
            *":/usr/local/bin:${shell_prefix}/bin:"*) ;;
            *) PATH=$(printf '%s' "$PATH" | sed "s!/usr/local/bin!/usr/local/bin:${shell_prefix}/bin!g") ;;
        esac
        case ":$PATH:" in
            *":/usr/local/sbin:${shell_prefix}/sbin:"*) ;;
            *) PATH=$(printf '%s' "$PATH" | sed "s!/usr/local/sbin!/usr/local/sbin:${shell_prefix}/sbin!g") ;;
        esac
        pathvarmunge MANPATH "$shell_prefix/share/man"
        pathvarmunge INFOPATH "$shell_prefix/share/info"
        export SYSTEM_VERSION_COMPAT=0
    fi

    # Homebrew variables
    if [ "$pkg_manager" = "homebrew" ]; then
        pathvarensure_front PATH "$shell_prefix/bin"
        pathvarmunge MANPATH "$shell_prefix/share/man"
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

    pathvarmunge PATH /Applications/MacVim.app/Contents/bin
    pathvarmunge MANPATH /Applications/MacVim.app/Contents/man

    # Default editor
    if [ "${TERM_PROGRAM:-}" = "vscode" ] || [ -n "${CODE_SHELL:-}" ]; then
        if [ "${__CFBundleIdentifier:-}" = "com.exafunction.windsurf" ]; then
            export EDITOR="windsurf --wait --reuse-window"
        elif [ -n "${CURSOR_TRACE_ID:-}" ]; then
            export EDITOR="cursor --wait --reuse-window"
        else
            export EDITOR="code --wait --reuse-window"
        fi
        export ALTERNATE_EDITOR=vim
        export GIT_EDITOR=vim
    elif command_on_path mvim; then
        export EDITOR="mvim --nofork --remote-tab-wait-silent +:"
        export ALTERNATE_EDITOR=vim
        export GIT_EDITOR=vim
    elif command_on_path gvim; then
        export EDITOR="gvim --nofork --remote-tab-wait-silent +:"
        export ALTERNATE_EDITOR=vim
        export GIT_EDITOR=vim
    elif command_on_path vim; then
        export EDITOR=vim
        export ALTERNATE_EDITOR=vi
    else
        export EDITOR=vi
    fi

    export COLORFGBG=${COLORFGBG:-"7;0"}
    export GTK_IM_MODULE=ibus
    export QT_IM_MODULE=ibus
    export XMODIFIERS="@im=ibus"
    export MATLAB_USE_USERPATH=1

    if command_on_path vim; then
        export FCEDIT="vim -E --noplugin -u ~/.vim/fc.vim"
    else
        export FCEDIT="vi"
    fi
    export VISUAL="$EDITOR"

    export PAGER=less
    export LESS="FRI"
    if ! [ "$(less -V | head -n1 | sed -E 's/^less ([0-9]+).*/\1/')" -ge 530 ]; then
        LESS="${LESS}X"
    fi
    export MANPAGER="$PAGER"

    if command_on_path bat; then
        export BAT_THEME="Monokai Extended"
        export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat --language=man --plain'"
    fi

    [ "$TERM" = "linux" ] && export LESS="${LESS}C"

    if command_on_path nvimpager; then
        export MANPAGER="nvimpager"
    fi

    export TEXMFHOME=$HOME/.texmf
    export PYTHONSTARTUP=$HOME/.pythonstartup

    __ncpu() {
        if command_on_path nproc; then
            nproc
            return
        fi
        case $(uname) in
            Darwin) /usr/sbin/sysctl -n hw.ncpu ;;
            *) echo 1 ;;
        esac
    }
    GOMAXPROCS=$(__ncpu); export GOMAXPROCS
    unset -f __ncpu
    GOPATH="$HOME/Documents/code/go"; export GOPATH
    pathvarmunge PATH "$GOPATH/bin"

    . "$HOME/.cargo/env"

    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
    PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"
    MANPATH="${HOME}/.nix-profile/share/man:/nix/var/nix/profiles/default/share/man:${MANPATH}"

    if [ -d "$HOME/local/perl5" ] && perl -Mlocal::lib -e1 2>/dev/null; then
        eval "$(perl -I"$HOME/local/perl5" -Mlocal::lib)"
    fi

    export MOSH_ESCAPE_KEY='~'
    export EMACS_SERVER_FILE=~/doom.emacs.d/server/server

    if [ -f ~/.doom.d/.doomgitconfig ]; then
        export DOOMGITCONFIG=~/.doom.d/.doomgitconfig
    fi

    if [ -d "$HOME/misc/build/git-tools" ]; then
        pathvarmunge PATH "$HOME/misc/build/git-tools"
        pathvarmunge MANPATH "$HOME/misc/build/git-tools"
    fi

    VSCODE_BIN_DIR="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    if [ -d "${VSCODE_BIN_DIR}" ]; then
        pathvarmunge PATH "${VSCODE_BIN_DIR}"
    fi

    if command_on_path asdf; then
        export ASDF_DATA_DIR="$HOME/.asdf"
        pathvarmunge PATH "$ASDF_DATA_DIR/shims"
    fi

    KREW_ROOT="${KREW_ROOT:-"$HOME/.krew"}"
    if [ -d "${KREW_ROOT}/bin" ]; then
        pathvarmunge PATH "${KREW_ROOT}/bin"
    fi
}

_my_profile_emit_export() {
    var=$1
    eval "is_set=\${${var}+x}"
    [ -n "$is_set" ] || return 0
    eval "val=\${$var}"
    printf 'export %s=%s\n' "$var" "$(shell_quote "$val")"
}

_my_profile_write_static_env_cache() {
    _my_profile_apply_static_env
    cat <<EOF
# Generated by ~/bin/refresh-bash-static-env.
# Regenerate this file after changing package managers, editors, or shell tooling.
EOF
    for var in \
        PATH MANPATH INFOPATH SYSTEM_VERSION_COMPAT EDITOR ALTERNATE_EDITOR \
        GIT_EDITOR COLORFGBG GTK_IM_MODULE QT_IM_MODULE XMODIFIERS \
        MATLAB_USE_USERPATH FCEDIT VISUAL PAGER LESS MANPAGER BAT_THEME \
        TEXMFHOME PYTHONSTARTUP GOMAXPROCS GOPATH MOSH_ESCAPE_KEY \
        EMACS_SERVER_FILE DOOMGITCONFIG ASDF_DATA_DIR KREW_ROOT
    do
        _my_profile_emit_export "$var"
    done
}
