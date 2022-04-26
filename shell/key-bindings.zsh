#     ____      ____
#    / __/___  / __/
#   / /_/_  / / /_
#  / __/ / /_/ __/
# /_/   /___/_/ key-bindings.zsh
#
# - $FZF_TMUX_OPTS
# - $FZF_CTRL_T_COMMAND
# - $FZF_CTRL_T_OPTS
# - $FZF_CTRL_R_OPTS
# - $FZF_ALT_C_COMMAND
# - $FZF_ALT_C_OPTS

# Key bindings
# ------------

# The code at the top and the bottom of this file is the same as in completion.zsh.
# Refer to that file for explanation.
if 'zmodload' 'zsh/parameter' 2>'/dev/null' && (( ${+options} )); then
  __fzf_key_bindings_options="options=(${(j: :)${(kv)options[@]}})"
else
  () {
    __fzf_key_bindings_options="setopt"
    'local' '__fzf_opt'
    for __fzf_opt in "${(@)${(@f)$(set -o)}%% *}"; do
      if [[ -o "$__fzf_opt" ]]; then
        __fzf_key_bindings_options+=" -o $__fzf_opt"
      else
        __fzf_key_bindings_options+=" +o $__fzf_opt"
      fi
    done
  }
fi

'emulate' 'zsh' '-o' 'no_aliases'

{

[[ -o interactive ]] || return 0

# CTRL-T - Paste the selected file path(s) into the command line
__fsel() {
  local cmd="${FZF_CTRL_T_COMMAND:-"command fd -H -t f -c always --strip-cwd-prefix 2> /dev/null"}"
  setopt localoptions pipefail no_aliases 2> /dev/null
  local item
  local accept=0
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-50%} --ansi --reverse --bind=ctrl-z:ignore,ctrl-u:preview-up,ctrl-d:preview-down --expect=ctrl-f --expect=ctrl-g $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" $(__fzfcmd) -m "$@" --preview="[[ ! -z {} ]] && bat --color=always --style=numbers {}" --preview-window="50%:wrap" | while read item; do
    if [[ $item = ctrl-f ]]; then
    elif [[ $item = ctrl-g ]]; then
      accept=1
    # enter key
    elif [[ -z "$item" ]]; then
      accept=1
    else
      # q for quoting
      # https://zsh.sourceforge.io/Doc/Release/Expansion.html
      echo -n "${EDITOR} ${(q)item}"
    fi
  done
  local ret=$?
  echo
  return accept
}

__fzfcmd() {
  [ -n "$TMUX_PANE" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "$FZF_TMUX_OPTS" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

fzf-file-widget() {
  LBUFFER="${LBUFFER}$(__fsel)"
  local accept=$?
  zle reset-prompt
  if [[ $accept = 1 ]]; then
    zle accept-line
  fi
  return 0
}
zle     -N            fzf-file-widget
bindkey -M emacs '^O' fzf-file-widget
bindkey -M vicmd '^O' fzf-file-widget
bindkey -M viins '^O' fzf-file-widget

# ALT-C - cd into the selected directory
fzf-cd-widget() {
  local cmd="${FZF_ALT_C_COMMAND:-"command fd -H -t d -c always --strip-cwd-prefix 2> /dev/null"}"
  setopt localoptions pipefail no_aliases 2> /dev/null
  local dir
  local item
  local accept=0
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-50%} --ansi --reverse --bind=ctrl-z:ignore,ctrl-u:preview-up,ctrl-d:preview-down --expect=ctrl-f --expect=ctrl-g $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m --preview="[[ ! -z {} ]] && command fd -H -c always . {} 2> /dev/null | sed 's;{}/;;'" --preview-window="50%:wrap" | while read item; do
  if [[ $item = ctrl-f ]]; then
  elif [[ $item = ctrl-g ]]; then
    accept=1
  elif [[ -z "$item" ]]; then
    accept=1
  else
    dir=$item
  fi
done

  if [[ -z "$dir" ]]; then
    zle redisplay
    return 0
  fi
  zle push-line # Clear buffer. Auto-restored on next prompt.
  BUFFER="cd -- ${(q)dir}"
  if [[ $accept = 1 ]]; then
    zle accept-line
  fi
  local ret=$?
  unset dir # ensure this doesn't end up appearing in prompt expansion
  zle reset-prompt
  return $ret
}
zle     -N            fzf-cd-widget
bindkey -M emacs '^T' fzf-cd-widget
bindkey -M vicmd '^T' fzf-cd-widget
bindkey -M viins '^T' fzf-cd-widget

# CTRL-R - Paste the selected command from history into the command line
# History direct output: https://github.com/junegunn/fzf/issues/477
fzf-history-widget() {
  local selected num
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
  selected=( $(fc -rl 1 | perl -ne 'print if !$seen{(/^\s*[0-9]+\**\s+(.*)/, $1)}++' |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort,ctrl-z:ignore --expect=ctrl-f --expect=ctrl-g $FZF_CTRL_R_OPTS --query=${(qqq)LBUFFER} +m" $(__fzfcmd)) )
  local ret=$?
  if [ -n "$selected" ]; then
    local accept=0
    if [[ $selected[1] = ctrl-f ]]; then
      accept=1
      shift selected
    fi
    if [[ $selected[1] = ctrl-g ]]; then
      accept=1
      shift selected
      zle accept-line
    fi
    num=$selected[1]
    if [ -n "$num" ]; then
      zle vi-fetch-history -n $num
      [[ $accept = 0 ]] && zle accept-line
    fi
  fi
  zle reset-prompt
  return $ret
}
zle     -N            fzf-history-widget
bindkey -M emacs '^R' fzf-history-widget
bindkey -M vicmd '^R' fzf-history-widget
bindkey -M viins '^R' fzf-history-widget

} always {
  eval $__fzf_key_bindings_options
  'unset' '__fzf_key_bindings_options'
}

__fzf-rg() {
  RG_PREFIX="rg --files-with-matches --smart-case"
  local selected item
  setopt localoptions pipefail no_aliases 2> /dev/null
  # TODO upgrade batgrep:
  # --search-pattern
  # --terminal-width=80 in fzf previewer always `$({ stty size 2>/dev/null || echo "22 80"; } | cut -d ' ' -f2)`
  # https://github.com/eth-p/bat-extras/pull/55
  # https://github.com/eth-p/bat-extras/pull/62
  selected=( $( eval $RG_PREFIX ${(qqq)LBUFFER} | lscolors | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-100%} --ansi --sort --bind=ctrl-z:ignore,ctrl-u:preview-up,ctrl-d:preview-down --expect=ctrl-f --expect=ctrl-g" fzf --preview="[[ ! -z {} ]] && if [[ -z {q} ]]; then bat --color=always {}; else (batgrep --smart-case --paging=always --pager=less --color --context 10 -p {q} {}); fi" --phony --query=${LBUFFER} --bind "change:reload:$RG_PREFIX {q} | lscolors" --preview-window="up,60%,border-bottom,+{2}+3/3,~3" ) )

  local ret=$?
  local accept=0
  if [ -n "$selected" ]; then
    if [[ $selected[1] = ctrl-f ]]; then
      shift selected
    fi
    if [[ $selected[1] = ctrl-g ]]; then
      accept=1
      shift selected
    fi
    item=$selected[1]
    echo -n "${EDITOR} ${(q)item}"
  fi

  echo
  return accept
}

fzf-rg() {
  LBUFFER="${LBUFFER}$(__fzf-rg)"
  local accept=$?
  zle reset-prompt
  if [[ $accept = 1 ]]; then
    zle accept-line
  fi
  return 0
}

zle     -N            fzf-rg
bindkey -M emacs '^E' fzf-rg
bindkey -M vicmd '^E' fzf-rg
bindkey -M viins '^E' fzf-rg
