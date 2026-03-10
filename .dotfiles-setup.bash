#!/usr/bin/env bash
set -eu

main () {
    local git_dir="$HOME/.dotfiles-git-dir"
    local git_dir_backup="${git_dir}-backup"
    local worktree="$HOME"
    config() {
        git --git-dir="${git_dir}" "$@"
    }

    if [ ! -e "${git_dir}" ] && [ -e "${git_dir_backup}" ]; then
        mv "${git_dir_backup}" "${git_dir}"
    fi
    if [ -e "${git_dir}" ]; then
        config config --local core.worktree "${worktree}"
        config config --local status.showUntrackedFiles no
        config submodule update --init --recursive
        return 0
    fi

    [ -e "${git_dir_backup}" ] && rm -rf "${git_dir_backup}"
    local repo="https://github.com/telotortium/dotfiles"
    local tmp_dir="$HOME/dotfiles-tmp"
    git clone --separate-git-dir="${git_dir}"  "${repo}" "${tmp_dir}"
    cp "${tmp_dir}/.gitmodules" "${worktree}"
    rm -rf "${tmp_dir}"

    # Set working tree
    config config --local core.worktree "${worktree}"

    # Checkout dotfiles from repo after attempting to save the existing files.
    existing_dotfiles () {
        config status --porcelain \
            | sed -ne '/^ / { s/^ *[^ ]* *\(.*\)$/\1/; p; }'
    }
    existing_dotfiles | while read -r x; do
        if config cat-file -e "HEAD:$x" 2>/dev/null; then
            config checkout HEAD -- "$x"
        fi
    done

    # Don't show untracked files, in order to ignore programs that dump their
    # configuration in $HOME.
    config config --local status.showUntrackedFiles no

    config submodule update --init --recursive
}

main "$@"
