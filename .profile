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

if [ -f "$HOME/.profile.static_env.lib.sh" ]; then
    . "$HOME/.profile.static_env.lib.sh"
fi

if [ -r "$HOME/.profile.static_env.sh" ] && [ -O "$HOME/.profile.static_env.sh" ]; then
    . "$HOME/.profile.static_env.sh"
elif command_on_path _my_profile_apply_static_env; then
    _my_profile_apply_static_env
fi

# Import ssh-agent settings
if command_on_path find-ssh-agent; then
    . find-ssh-agent
fi

# Export MOSH_CONNECTION variable, which can be used by later code to determine
# if connection was made over Mosh.
if command_on_path pstree && pstree -p $$ | grep -q '[m]osh-server'; then
    export MOSH_CONNECTION=1
else
    export MOSH_CONNECTION=
fi

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi

unset -f _my_profile_apply_static_env _my_profile_emit_export _my_profile_write_static_env_cache 2>/dev/null
