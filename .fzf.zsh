# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/rmi1/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/Users/rmi1/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/Users/rmi1/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/Users/rmi1/.fzf/shell/key-bindings.zsh"
