# .bash_profile

if [ -f ~/.profile ]; then
    . ~/.profile
fi

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
if [ -e /home/rmi1/.nix-profile/etc/profile.d/nix.sh ]; then . /home/rmi1/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

# Macports bash-completion
if [ -f /opt/local/etc/profile.d/bash_completion.sh ]; then
    . /opt/local/etc/profile.d/bash_completion.sh
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

. ~/.bash-history-sqlite/bash-profile.stub
