[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(direnv hook zsh)"

# FNM (fast Node manager) + nvm-compatible wrapper
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell zsh)"
fi
nvm() {
    case "$1" in
        use)
            shift
            if [ "${1:-}" = "--silent" ]; then
                shift
            fi
            fnm use "$@"
            ;;
        install)
            shift
            fnm install "$@"
            ;;
        uninstall)
            shift
            fnm uninstall "$@"
            ;;
        ls|list)
            fnm list
            ;;
        ls-remote)
            fnm list-remote
            ;;
        current)
            fnm current
            ;;
        alias)
            echo "nvm alias is not supported by fnm" >&2
            echo "Use .nvmrc or fnm default instead" >&2
            return 1
            ;;
        *)
            echo "nvm: unsupported subcommand '$1' (using fnm)" >&2
            echo "Try: fnm $*" >&2
            return 1
            ;;
    esac
}
set -o vi

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
