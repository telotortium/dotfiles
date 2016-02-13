# dotfiles

Contains my dotfiles

## Setup

I'm currently placing my working tree in my home directory while locating the
Git directory elsewhere, as inspired by [this Hacker News post][1]. To set this
up upon the initial clone, run these commands:

```shell
git clone --separate-git-dir="$HOME/.dotfiles"  \
    https://github.com/telotortium/dotfiles "$HOME/dotfiles-tmp"
cp ~/dotfiles-tmp/.gitmodules ~
rm -r ~/dotfiles-tmp/
alias config='git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'

# Checkout dotfiles from repo after attempting to save the existing files.
config stash save
config tag dotfiles-before-initial-checkout stash@{0}
existing_dotfiles () {
    config status --porcelain \
        | sed -ne '/^ / { s/^ *[^ ]* *\(.*\)$/\1/; p; }' \
}
existing_dotfiles | while read -r x; do config checkout HEAD -- "$x"; done

# Don't show untracked files, in order to ignore programs that dump their
# configuration in $HOME.
config config --local status.showUntrackedFiles no

config submodule update --init --recursive
```

[1]: https://news.ycombinator.com/item?id=11071754
