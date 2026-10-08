# Keep theme variables together so programs inherit one consistent choice.
_set_terminal_background() {
    case "${1:-}" in
        light)
            export TERM_BACKGROUND=light
            export COLORFGBG='0;15'
            export BAT_THEME='Monokai Extended Light'
            ;;
        dark)
            export TERM_BACKGROUND=dark
            export COLORFGBG='15;0'
            export BAT_THEME='Monokai Extended'
            ;;
        *) return 1 ;;
    esac
    _TERM_BACKGROUND_LAST_KNOWN=$1
}

_terminal_background_from_app() {
    /usr/bin/osascript "$HOME/bin/terminal-background" "$1" "${TERM_PROGRAM:-}" 2>/dev/null
}

_terminal_background_system_appearance() {
    /usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null || printf 'Light\n'
}

refresh_terminal_background() {
    local appearance detected terminal_tty tmux_background

    case "${TERM_BACKGROUND_OVERRIDE:-}" in
        light|dark)
            _set_terminal_background "$TERM_BACKGROUND_OVERRIDE"
            return 0
            ;;
    esac
    _set_terminal_background "${_TERM_BACKGROUND_LAST_KNOWN:-${TERM_BACKGROUND:-}}" || :

    if [[ -n "${TMUX:-}" ]]; then
        tmux_background=$(tmux show-environment TERM_BACKGROUND 2>/dev/null) || tmux_background=
        tmux_background=${tmux_background#TERM_BACKGROUND=}
        # A new attachment can supply a new fallback. Do not repeatedly replace
        # a later observation with the same tmux environment value.
        if [[ "$tmux_background" != "${_TERM_BACKGROUND_TMUX_ENV:-}" ]]; then
            _TERM_BACKGROUND_TMUX_ENV=$tmux_background
            _set_terminal_background "$tmux_background" || :
        fi
    fi

    # Remote Bash retains the login or attachment value. Reading terminal replies
    # here would compete with keyboard input; Vim handles its own replies instead.
    [[ -z "${SSH_TTY:-}" && "${OSTYPE:-}" == darwin* ]] || return 0
    [[ -t 0 && -t 1 && "${TERM:-}" != dumb ]] || return 0
    case "${TERM_PROGRAM:-}" in iTerm.app|Apple_Terminal) ;; *) return 0 ;; esac
    [[ "${_TERM_BACKGROUND_LAST_POLL:-}" != "$SECONDS" ]] || return 0
    _TERM_BACKGROUND_LAST_POLL=$SECONDS

    if [[ -n "${TMUX:-}" ]]; then
        terminal_tty=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{client_tty}' 2>/dev/null) || return 0
    else
        terminal_tty=$(tty 2>/dev/null) || return 0
    fi
    [[ -n "$terminal_tty" ]] || return 0

    appearance=$(_terminal_background_system_appearance)
    if [[ "$appearance" == "${_TERM_BACKGROUND_LAST_APPEARANCE:-}" ]] &&
        (( SECONDS < ${_TERM_BACKGROUND_NEXT_QUERY_AT:-0} )); then
        return 0
    fi
    _TERM_BACKGROUND_LAST_APPEARANCE=$appearance
    # AppleScript can take hundreds of milliseconds. Query at the next prompt or
    # command after an appearance change, or after a minute to catch profile changes.
    _TERM_BACKGROUND_NEXT_QUERY_AT=$((SECONDS + 5))
    detected=$(_terminal_background_from_app "$terminal_tty") || return 0
    if _set_terminal_background "$detected"; then
        _TERM_BACKGROUND_NEXT_QUERY_AT=$((SECONDS + 60))
    fi
    return 0
}

term-background() {
    case "${1:-}" in
        '') ;;
        light|dark)
            export TERM_BACKGROUND_OVERRIDE=$1
            _set_terminal_background "$1"
            ;;
        auto)
            unset TERM_BACKGROUND_OVERRIDE _TERM_BACKGROUND_LAST_POLL _TERM_BACKGROUND_LAST_APPEARANCE
            unset _TERM_BACKGROUND_NEXT_QUERY_AT _TERM_BACKGROUND_TMUX_ENV
            refresh_terminal_background
            ;;
        *)
            printf 'Usage: term-background [light|dark|auto]\n' >&2
            return 2
            ;;
    esac
    printf '%s\n' "${TERM_BACKGROUND:-unknown}"
}

if ! _set_terminal_background "${TERM_BACKGROUND_OVERRIDE:-}"; then
    if ! _set_terminal_background "${_TERM_BACKGROUND_LAST_KNOWN:-${TERM_BACKGROUND:-}}"; then
        case "${COLORFGBG:-}" in
            '0;15') _set_terminal_background light ;;
            '15;0') _set_terminal_background dark ;;
        esac
    fi
fi

_install_terminal_background_hooks() {
    local hook
    local -a updated_precmd=() updated_preexec=()
    for hook in "${precmd_functions[@]}"; do
        [[ "$hook" == refresh_terminal_background ]] || updated_precmd+=("$hook")
    done
    for hook in "${preexec_functions[@]}"; do
        case "$hook" in
            colorfgbg_from_system_appearance|refresh_terminal_background) ;;
            *) updated_preexec+=("$hook") ;;
        esac
    done
    precmd_functions=("${updated_precmd[@]}" refresh_terminal_background)
    preexec_functions=("${updated_preexec[@]}" refresh_terminal_background)
}

# Sourcing this file also updates an existing shell without reloading all dotfiles.
_install_terminal_background_hooks
