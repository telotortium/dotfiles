# .bash_profile
# shellcheck disable=SC1090,SC1091

if [ -f ~/.profile ]; then
    source ~/.profile
fi
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

if [[ $- == *i* && -f ~/.bashrc ]]; then
    # Prevent recursive includes of ~/.bashrc
    while true; do
        for src in "${BASH_SOURCE[@]}"; do
            if [[ "${src}" = ~/.bashrc ]]; then
                break 2
            fi
        done
        source ~/.bashrc
        break
    done
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
