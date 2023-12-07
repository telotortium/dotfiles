# Load the builtin bash-preexec from iTerm2 Shell Integration.
_load_bash_preexec_from_iterm2 () {
    # shellcheck disable=SC1090
    source <(
        awk '
            /^_install_bash_preexec \(\)/ { p=1; }
            /^unset -f _install_bash_preexec/ { print; exit; }
            { if (p==1) {print;}}
        ' < ~/.iterm2_shell_integration.bash
    )
}
_load_bash_preexec_from_iterm2
unset -f _load_bash_preexec_from_iterm2
