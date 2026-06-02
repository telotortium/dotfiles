# .bash_profile
# shellcheck disable=SC1090,SC1091

# Include guard
if [ -n "${__MY_BASH_PROFILE_SOURCED:-}" ]; then
    return
fi
__MY_BASH_PROFILE_SOURCED=1

if [ -f ~/.profile ]; then
    source ~/.profile
fi
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

if [[ -f ~/.bashrc ]]; then
    source ~/.bashrc
fi

if [[ "${TERM_PROGRAM:-}" = "iTerm.app" ]] && [[ -e "${HOME}/.iterm2_shell_integration.bash" ]]; then
    source "${HOME}/.iterm2_shell_integration.bash"
fi

if [[ $- = *i* ]] && [[ "${__CFBundleIdentifier:-}" = com.openai.codex* ]] && [[ -z "${CODE_SHELL:-}" ]]; then
    code-shell
fi
