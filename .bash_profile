# .bash_profile

if [ -f ~/.profile ]; then
    . ~/.profile
fi

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
if [ -e /home/rmi1/.nix-profile/etc/profile.d/nix.sh ]; then . /home/rmi1/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
