# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "${PS1:-}" ] && return

# Include guard
if [ -n "${__MY_BASHRC_SOURCED:-}" ]; then
    return
fi
__MY_BASHRC_SOURCED=1

BASH_LOAD_STATE=${BASH_LOAD_STATE:-1}
BASH_STATE_FILE=${BASH_STATE_FILE:-"/tmp/bash-load-state-${USER}-${EUID}"}
if [[ "${BASH_LOAD_STATE:-0}" -ne 0 ]] && [[ -r "${BASH_STATE_FILE}" ]]; then
    if [[ -O "${BASH_STATE_FILE}" ]]; then
        echo "${HOME}/.bashrc: loading from ${BASH_STATE_FILE}. If you need to reinitialize that file, run \`BASH_LOAD_STATE=0 bash -l\`" 1>&2
        # shellcheck disable=SC1090
        source "$BASH_STATE_FILE"
        return
    else
        echo "${HOME}/.bashrc: ${BASH_STATE_FILE} exists but is not owned by you. Will try to write to it at the end of this script, but will probably fail. You should investigate." 1>&2
    fi
fi
echo "${HOME}/.bashrc: loading full Bashrc. Will run \`source ~/bin/bash-dump-state >\"${BASH_STATE_FILE}\"\` afterward." 1>&2

# Since we cache the result of loading ~/.bash_profile most of the time, make
# sure to evaluate it when we want to regenerate ${BASH_STATE_FILE}.
# shellcheck disable=SC1090,SC1091
source ~/.bash_profile

# shellcheck disable=SC1091
[ -f "$HOME/.common.sh" ] && source "$HOME/.common.sh"

# Set umask to exclude group and other write permissions
umask 022

# # Import ssh-agent settings
# [ -f "$(command -v find-ssh-agent)" ] && source find-ssh-agent

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# Enable extended glob patterns
shopt -s extglob

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

if which loginctl > /dev/null && loginctl >& /dev/null; then
    if loginctl show-user | grep KillUserProcesses | grep -q yes; then
        echo "systemd is set to kill user processes on logoff"
        echo "This will break screen, tmux, emacs --daemon, nohup, etc"
        echo "Tell the sysadmin to set KillUserProcesses=no in /etc/systemd/login.conf"
    fi
fi

CDPATH=.:~:~/Documents/org

# Terminal setup
precmd_functions+=(precmd_prompt_exit_status)
# Disable flow control
stty stop undef
# If in GNOME Terminal, set the appropriate TERM
if [ "${COLORTERM:-}" = "gnome-terminal" ]; then
    export TERM="gnome-256color"
fi
# Handle screen pecularities
if [ -n "$STY" ]; then
    # byobu likes to set SSH_AUTH_SOCK for some reason. Bad!
    # shellcheck disable=SC1091
    [ -f "$HOME/bin/find-ssh-agent" ] && source "$HOME/bin/find-ssh-agent"
fi
case "$TERM" in
putty*)
    # Get arrow keys to work correctly: put terminal in application keys mode
    # and reassign inputrc
    setterm -appcursorkeys on
    export INPUTRC="$HOME/.inputrc-putty"
    ;;
esac

# set a fancy prompt (non-color, unless we know we "want" color)
bash_prompt_setup() {
    # make tput act as if on an ANSI terminal if the TERM environment
    # variable specifies an unavailable TERM (we want to keep TERM since
    # we're usually gonna SSH to a computer with the right TERM anyway,
    # and ANSI is a lowest-common-denominator TERM)
    if ! tput longname &> /dev/null; then
        tput() { TERM=ansi command tput "$@"; }
    fi

    # normal colors
    local K; K="\[$(tput setaf 0)\]"    # black
    local R; R="\[$(tput setaf 1)\]"    # red
    local G; G="\[$(tput setaf 2)\]"    # green
    local Y; Y="\[$(tput setaf 3)\]"    # yellow
    local B; B="\[$(tput setaf 4)\]"    # blue
    local M; M="\[$(tput setaf 5)\]"    # magenta
    local C; C="\[$(tput setaf 6)\]"    # cyan
    local W; W="\[$(tput setaf 7)\]"    # white

    # background colors
    local BGK; BGK="\[$(tput setab 0)\]"
    local BGR; BGR="\[$(tput setab 1)\]"
    local BGG; BGG="\[$(tput setab 2)\]"
    local BGY; BGY="\[$(tput setab 3)\]"
    local BGB; BGB="\[$(tput setab 4)\]"
    local BGM; BGM="\[$(tput setab 5)\]"
    local BGC; BGC="\[$(tput setab 6)\]"
    local BGW; BGW="\[$(tput setab 7)\]"

    # shellcheck disable=SC2127
    case $TERM in
    # Assume these terminals support at least 16 colors, since TERM is often
    # set to these even if the terminal supports more colors.
    xterm|rxvt|screen|putty)
        ;;&
    # Explicitly enable for all terminals with >8 colors
    *-[0-9]+([0-9])color?(-*))
        # bright colors
        local BK; BK="\[\033[0;90m\]"
        local BR; BR="\[\033[0;91m\]"
        local BG; BG="\[\033[0;92m\]"
        local BY; BY="\[\033[0;93m\]"
        local BB; BB="\[\033[0;94m\]"
        local BM; BM="\[\033[0;95m\]"
        local BC; BC="\[\033[0;96m\]"
        local BW; BW="\[\033[0;97m\]"

        # bright background colors
        local BBGK; BBGK="\[\033[0;100m\]"
        local BBGR; BBGR="\[\033[0;101m\]"
        local BBGG; BBGG="\[\033[0;102m\]"
        local BBGY; BBGY="\[\033[0;103m\]"
        local BBGB; BBGB="\[\033[0;104m\]"
        local BBGM; BBGM="\[\033[0;105m\]"
        local BBGC; BBGC="\[\033[0;106m\]"
        local BBGW; BBGW="\[\033[0;107m\]"
        ;;

    # Simulate bright colors with normal if bright colors are not supported
    *)
        # Don't warn if unused
        # shellcheck disable=SC2034
        {
            local BK; BK="${K}"
            local BR; BR="${R}"
            local BG; BG="${G}"
            local BY; BY="${Y}"
            local BB; BB="${B}"
            local BM; BM="${M}"
            local BC; BC="${C}"
            local BW; BW="${W}"

            local BBGK; BBGK="${BGK}"
            local BBGR; BBGR="${BGR}"
            local BBGG; BBGG="${BGG}"
            local BBGY; BBGY="${BGY}"
            local BBGB; BBGB="${BGB}"
            local BBGM; BBGM="${BGM}"
            local BBGC; BBGC="${BGC}"
            local BBGW; BBGW="${BGW}"
        }
        ;;

    esac

    # Don't warn if unused
    # shellcheck disable=SC2034
    {
        local BD; BD="\[$(tput bold)\]" # bold
        local UL; UL="\[$(tput smul)\]" # underline

        # reset terminal to normal text
        local RS; RS="\[$(tput sgr0)\]"
    }

    ##################
    # Prompts themselves

    # This expression should be eval'd in the prompt, not here.
    # shellcheck disable=SC2016
    local __pwd_escaped='$(__pwd=${PWD#$HOME};
        if [ "$__pwd" = "$PWD" ]; then
            __pwd=$(printf "%q" "${__pwd}");
        else
            __pwd=${__pwd%/};
            if [ -n "$__pwd" ]; then
                __pwd=${__pwd#/};
                __pwd=$(printf "~/%q" "${__pwd}");
            else
                __pwd="~";
            fi;
        fi;
        printf "%s" "${__pwd}";)'

    unset PS1 PS2

    if [ "$TERM" = "dumb" ]; then
        PS1='\u@\h:'"${__pwd_escaped}"'\$ '
        PS2='… '
        return 0
    fi

    # If this is an xterm set the title to user@host:dir
    case "$TERM" in
    xterm*|rxvt*|screen*|putty*|*-256color)
        eval $'precmd_xterm_title () {
            printf "\\033]0;%s: %s\\007" "${USER}@${HOSTNAME}" "'"${__pwd_escaped}"'"
        }'
        precmd_functions+=(precmd_xterm_title)
        ;;
    esac

    _my_prompt_command() {
        # Record exit status of executed command.
        precmd_prompt_exit_status () {
            # $__bp_last_ret_value is set by bash-preexec to be the return value of the
            # command executed at the prompt.
            # shellcheck disable=SC2154
            __PROMPT_EXIT_STATUS=$__bp_last_ret_value
        }

        # Set color based on the exit status of the lsat command.
        # This expression should be eval'd in the prompt, not here.
        # shellcheck disable=SC2016
        local exit_status_cmd='$(test "$__PROMPT_EXIT_STATUS" = 0 && printf %s "'${G}'" || printf %s "'${BR}'")'
        PS1="${1}[${2}\\u${3}@${4}\\h${5}]${6} ${7}${__pwd_escaped}${8}"$'\n'
        # Second line of prompt - start with `:` and end with `;` to allow
        # copying commands straight from the shell and re-executing them
        # without having to edit them. The `$`/`#` prompt is preceded by
        # a backslash to prevent any interpretation by the shell - this
        # requires 3 backslashes before `$` in `PS1`, since Bash interprets
        # backslashes as escapes when evaluating `PS1`.
        PS0="${RS}"  # Always reset before command output starts.
        PS1="${PS1}${9}: ${10}\\D{%F %k:%M:%S} \! ${exit_status_cmd}"'\\\$'";${11} "
        PS2="${12}…${13} "
    }

    if [ $EUID = 0 ]; then
        _my_prompt_command "${BR}" "${RS}" "${BR}" "${RS}" "${BR}" "${RS}" "${BR}""${UL}" "${RS}" \
            "${R}" "" "${R}" \
            "${R}" "${RS}"
    else
        _my_prompt_command "${BB}" "${RS}" "${BB}" "${RS}" "${BB}" "${RS}" "${BC}""${UL}" "${RS}" \
            "${C}" "" "${R}" \
            "${R}" "${RS}"
    fi
    unset _my_prompt_command
}

bash_prompt_setup
unset bash_prompt_setup

# Replace the edit-and-execute-command bindings, which use VISUAL and EDITOR,
# with a custom function after
# <http://gnu-bash.2382.n7.nabble.com/edit-and-execute-command-is-appropriately-named-weird-td3617.html> (retrieved 2013-01-14).
__bind_edit_in_editor()
{
        local p=${READLINE_POINT} TMPF=/tmp/readline-buffer.$$.$RANDOM

        tput bold
        echo Current command below. Will execute edited command after editor closes.
        printf "%s\n" "$READLINE_LINE" | tee "$TMPF"
        cp -f "$TMPF" "$TMPF.backup"
        tput sgr0
        ${FCEDIT} "$TMPF" && READLINE_LINE=$(< "$TMPF")
        if cmp "$TMPF" "$TMPF.backup" &>/dev/null; then
            rm -f "$TMPF" "$TMPF.backup"
            return 0
        fi
        rm -f "$TMPF" "$TMPF.backup"
        READLINE_POINT=$p # or p or ${#READLINE_LINE} or ...

        # Execute the edited command with eval to ensure BASH_COMMAND is set correctly.
        # Need to save the command to history manually, since we're using `eval`.
        printf '%s\n' "$READLINE_LINE" 1>&2
        builtin history -s "$READLINE_LINE"
        eval "$READLINE_LINE"
        # Unset READLINE_LINE, since we've just executed the command.
        READLINE_LINE=""
}
bind -m vi -x '"v":__bind_edit_in_editor'
bind -m emacs -x '"\C-x\C-e":__bind_edit_in_editor'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    # shellcheck disable=SC1090,SC1091
    source ~/.bash_aliases
fi

if command_on_path register-python-argcomplete-3.9 && \
    command_on_path pipx; then
    eval "$(register-python-argcomplete-3.9 pipx)"
fi

# History control
# no duplicate entries, and ignore entries starting with space
HISTCONTROL=ignorespace:erasedups
# Don't truncate history
HISTSIZE=-1; unset HISTFILESIZE
# Unset HISTIGNORE, since we're using BASH_HISTORY_SQLITE_IGNORE instead.
# HISTIGNORE stops commands from having preexec commands run for them if
# they match the patterns in HISTIGNORE.
BASH_HISTORY_SQLITE_IGNORE="${HISTIGNORE:-"&:ls:ls:mutt:[bf]g:exit:exec:exec *"}"
unset HISTIGNORE
# Set HISTTIMEFORMAT
HISTTIMEFORMAT="[%F %T %z] "
# Store multi-line command lines correctly
shopt -s cmdhist lithist
# Allow editing history lines on failure or from history expansion
shopt -s histreedit histverify

# Save and reload the history after each command finishes
shopt -s histappend                      # append to history, don't overwrite
precmd_history_append () { history -a; }
precmd_functions+=(precmd_history_append)

# shellcheck disable=SC1090,SC1091
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Use `fd` instead of `find` for faster `fzf` - see
# https://spin.atomicobject.com/2020/02/13/command-line-fuzzy-find-with-fzf/
export FZF_DEFAULT_COMMAND="fd --unrestricted --follow --exclude \".git\" . \"$HOME\""
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd -t d --unrestricted --follow --exclude \".git\" ."
_fzf_compgen_path() {
    fd --type f --hidden --follow --exclude .git . "$1"
}
_fzf_compgen_dir() {
    fd --type d . "$1"
}

# Multiline preview window for history search (see
# https://github.com/junegunn/fzf/issues/577#issuecomment-473241837)
GSED=$(case "$(uname -s)" in Linux) echo "sed" ;; *) echo "gsed" ;; esac)
export FZF_CTRL_R_OPTS="--preview 'echo {} |$GSED -e \"s/^ *\([0-9]*\) *//\" -e \"s/^\\(.\\{0,\$COLUMNS\\}\\).*$/\\1/\"; echo {} |$GSED -e \"s/^ *[0-9]* *//\" -e \"s/^.\\{0,\$COLUMNS\\}//g\" -e \"s/.\\{1,\$((COLUMNS-2))\\}/⏎ &\\n/g\"' --preview-window down:5 --bind ?:toggle-preview"

# BEGIN eval "$(direnv hook bash)"
# Based on that command, but change to use bash-preexec instead.
_direnv_install() {
    _direnv_hook() {
      local previous_exit_status=$?;
      trap -- '' SIGINT;
      eval "$(direnv export bash)";
      trap - SIGINT;
      return $previous_exit_status;
    };
    local _direnv_install=1
    for cmd in "${precmd_functions[@]}"; do
        if [[ "$cmd" == "_direnv_hook" ]]; then
            _direnv_install=0
            break
        fi
    done
    if [[ "$_direnv_install" -eq 1 ]]; then
        precmd_functions+=("_direnv_hook")
    fi
}
_direnv_install
unset -f _direnv_install
# END eval "$(direnv hook bash)"

# Enable Bash completion for Homebrew, Macports, and Linux system-wide Bash completion.
if [ -f /etc/bash_completion ]; then
    # shellcheck disable=SC1090,SC1091
    source /etc/bash_completion
fi
# Macports bash-completion
if [ -f /opt/local/etc/profile.d/bash_completion.sh ]; then
    # shellcheck disable=SC1090,SC1091
    source /opt/local/etc/profile.d/bash_completion.sh
fi
# Homebrew bash-completion
shell_path=$(command -v "$SHELL")
brew_path="${shell_path%/bin/*}/bin/brew"

if [[ -x "$brew_path" ]]; then
    brew_prefix=$("$brew_path" --prefix)
    if [[ -d "$brew_prefix/etc/bash_completion.d" ]]; then
        # shellcheck disable=SC1090,SC1091
        source "$brew_prefix/etc/profile.d/bash_completion.sh"
    fi
fi

command_on_path sshrc && complete -F _ssh sshrc

# shellcheck disable=SC1090,SC1091
source ~/.bash-history-sqlite/bash-profile.stub
# Redefine to filter by shell session
dbhistory() {
    local OPTIND; OPTIND=1  # Reset OPTIND to allow getopts to work when this function is called multiple times.
    local same_session; same_session="OR"
    local opt
    while getopts s opt; do
        case "$opt" in
            s) same_session="AND" ;;
            *) echo "Usage: [-s (restrict to commands from same session)]"; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    sqlite3 -separator '#' "${HISTDB}" "select command_id, command from command where 1=1 ${same_session} shellsession = '${HISTSESSION}' order by command_id DESC;" | awk -F'#' '/^[0-9]+#/ {printf "%8s    %s\n", $1, substr($0,index($0,FS)+1); next} { print $0; }'
}
# Use bash-history-sqlite database for history search instead of builtin
# history, since the latter gets truncated every so often.
__fzf_history_bash_history_sqlite__() {
  local output opts script
  opts="--height ${FZF_TMUX_HEIGHT:-40%} --bind=ctrl-z:ignore $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index \"--bind=ctrl-r:toggle-sort,ctrl-d:execute(echo {} | awk '{ sub(/^[^0-9]*/, \\\"\\\", \$1); print \$1 }' | sqlite3 ${HISTDB} 'delete from command where command_id = '\"\$(cat)\"';'; echo Deleted command {}; sleep 0.5)+exclude\" $FZF_CTRL_R_OPTS +m --read0"
  # This is a Python script, not a shell expression.
  # shellcheck disable=SC2016
  script='
import os
import sqlite3

conn = sqlite3.connect(os.environ["HISTDB"])
same_session = os.environ["SAME_SESSION"]
try:
    same_session = int(same_session)
except ValueError:
    pass
c = conn.cursor()
c.execute(f"""
    SELECT MAX(command_id) AS command_id, command
    FROM command
    WHERE shellsession {"=" if same_session else "!="} ?
    GROUP BY command
    ORDER BY command_id DESC
""", (os.environ["HISTSESSION"],))
width = 0
for row in c:
    # Set width of formatted integers. Since we are descending in command_id
    # order, the first row always has the maximum width.
    if width == 0:
        width = len(str(row[0]))
    print(f"""{"*" if same_session else " "}{row[0]:{width}}\t{row[1]}""", end="\0")
conn.close()'
  output=$(
    { HISTDB="${HISTDB}" HISTSESSION="${HISTSESSION}" SAME_SESSION=1 python3 -c "$script"; HISTDB=${HISTDB} HISTSESSION=${HISTSESSION} SAME_SESSION=0 python3 -c "$script"; } |
      FZF_DEFAULT_OPTS="$opts" $(__fzfcmd) --read0 --query "$READLINE_LINE"
  ) || return
  READLINE_LINE=${output#*$'\t'}
  if [[ -z "$READLINE_POINT" ]]; then
    echo "$READLINE_LINE"
  else
    READLINE_POINT=0x7fffffff
  fi
}
eval "$(printf '__fzf_history_builtin__ ()\n%s' "$(declare -f __fzf_history__ | sed 1d)")"
eval "$(printf '__fzf_history__ ()\n%s' "$(declare -f __fzf_history_bash_history_sqlite__ | sed 1d)")"

dbcmd ()
{
    sqlite3 "${HISTDB}" "select command from command where command_id=\"${1}\";"
}

if [ -n "$TMUX" ]; then
    function refresh_tmux_env {
        # Test again - in case we accidentally installed this function with
        # a broken `$TMUX`, we can run `unset TMUX` and then errors from this
        # function won't show anymore, without having to spawn a new shell.
        if [ -n "$TMUX" ]; then
            while IFS= read -r line; do
                if [ "$line" != "${line#-*}" ]; then
                    # Line starts with -, which means it's removed from the Tmux
                    # environment, so skip it.
                    continue
                fi
                var="${line%%=*}"
                val="${line#*=}"
                if [ "$(eval echo "\$$var")" != "$val" ]; then
                    echo "Setting $var to $val" 1>&2
                    export "$var=$val"
                fi
            done < <(tmux show-environment)
        fi
    }
    preexec_functions+=(refresh_tmux_env)
fi

if [[ "$(uname -s)" = "Darwin" ]]; then
    function colorfgbg_from_system_appearance {
        if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]]; then
          # Dark mode
          export COLORFGBG="15;0"
          export BAT_THEME="Monokai Extended"
        else
          # Light Mode
          export COLORFGBG="0;15"
          export BAT_THEME="Monokai Extended Light"
        fi
    }
    preexec_functions+=(colorfgbg_from_system_appearance)
fi

# Function to save current shell options and disable failglob
save_shell_options() {
    _saved_shopt=$(shopt -p failglob)
    shopt -u failglob
}

# Function to restore shell options and set failglob before command execution
restore_shell_options() {
    eval "$_saved_shopt"
    unset _saved_shopt
    shopt -s failglob
}
precmd_functions+=(save_shell_options)
preexec_functions+=(restore_shell_options)

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# shellcheck disable=SC1090,SC1091
{
    # Load .bash-preexec.sh if Iterm2 Shell Integration doesn't load.
    [[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
    # Load Iterm2 Shell Integration - it also includes bash-preexec.
    [[ -f ~/.iterm2_shell_integration.bash ]] && source ~/.iterm2_shell_integration.bash

    # LOCAL SETTINGS
    [[ -f ~/.bashrc.local ]] && . ~/.bashrc.local
}

echo "${HOME}/.bashrc: Running \`source ~/bin/bash-dump-state >\"${BASH_STATE_FILE}\"\` to save state." 1>&2
mkdir -p "${BASH_STATE_FILE%/*}"
# shellcheck disable=SC1090,SC1091
source ~/bin/bash-dump-state >"${BASH_STATE_FILE}"
