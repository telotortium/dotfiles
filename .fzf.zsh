# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/bytedance/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/Users/bytedance/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/Users/bytedance/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/Users/bytedance/.fzf/shell/key-bindings.zsh"
