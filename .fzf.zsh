# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/robert/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/Users/robert/.fzf/bin"
fi

# Replace `source <(fzf --zsh)`
source ~/.fzf/shell/key-bindings.zsh
source ~/.fzf/shell/completion.zsh
