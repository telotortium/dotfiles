set -eu

main () {
    local git_dir="$HOME/.dotfiles"
    local git_dir_backup="${git_dir}-backup"
    if [ -e "${git_dir_backup}" ]; then
        echo "Backup directory ${git_dir_backup} exists -- " \
            "move and try again" 1>&2
        return 1;
    fi
    [ -e "${git_dir}" ] && mv "${git_dir}" "${git_dir_backup}"
    local repo="https://github.com/telotortium/dotfiles"
    local tmp_dir="$HOME/dotfiles-tmp"
    local working_dir="$HOME"
    git clone --separate-git-dir="${git_dir}"  "${repo}" "${tmp_dir}"
    cp "${tmp_dir}/.gitmodules" "${working_dir}"
    rm -rf "${tmp_dir}"
    config() {
        git --git-dir="${git_dir}" --work-tree="${working_dir}" "$@"
    }

    # Checkout dotfiles from repo after attempting to save the existing files.
    existing_dotfiles () {
        config status --porcelain \
            | sed -ne '/^ / { s/^ *[^ ]* *\(.*\)$/\1/; p; }'
    }
    existing_dotfiles | while read -r x; do config checkout HEAD -- "$x"; done

    # Don't show untracked files, in order to ignore programs that dump their
    # configuration in $HOME.
    config config --local status.showUntrackedFiles no

    config submodule update --init --recursive
}

main "$@"
