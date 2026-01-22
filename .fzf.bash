# Setup fzf
# ---------
if [[ ! "$PATH" == *"${HOME}/.fzf/bin"* ]]; then
  PATH="${PATH:+${PATH}:}${HOME}/.fzf/bin"
fi

# Replace `eval "$(fzf --bash)"`
source ~/.fzf/shell/key-bindings.bash
source ~/.fzf/shell/completion.bash
