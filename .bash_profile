# .bash_profile

if [ -f ~/.profile ]; then
    . ~/.profile
fi

if [[ $- == *i* && -f ~/.bashrc ]]; then
    . ~/.bashrc
fi
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi # added by Nix installer
