# SPDX-License-Identifier: GPL-3.0-or-later
# Editing mode and key bindings.
#
# Default is vi: Esc, h/j/k/l, w/b/e, and the usual command-mode editing.
# `keymap emacs` switches to a plain readline-style shell and is remembered
# for the next session.
#
# The arrow keys keep the same behaviour in every mode and keymap: up/down
# search history by the prefix already typed, left/right move by character,
# Ctrl+Left/Right jump by word, Home/End go to the line edges. Nothing else
# grabs the arrow keys.

# Nothing to bind when ZLE is not running (scripts, `zsh -c`, cron jobs).
if [[ ! -o zle ]]; then
  return 0
fi

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

autoload -Uz edit-command-line
zle -N edit-command-line

typeset -g ARCHWAY_KEYMAP_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archway/zsh-keymap"

_archway_bind_common() {
  local keymap=$1
  bindkey -M "$keymap" '^[[A' up-line-or-beginning-search
  bindkey -M "$keymap" '^[[B' down-line-or-beginning-search
  bindkey -M "$keymap" '^[[C' forward-char
  bindkey -M "$keymap" '^[[D' backward-char
  bindkey -M "$keymap" '^[[1;5C' forward-word
  bindkey -M "$keymap" '^[[1;5D' backward-word
  bindkey -M "$keymap" '^[[H' beginning-of-line
  bindkey -M "$keymap" '^[[F' end-of-line
  bindkey -M "$keymap" '^[[1~' beginning-of-line
  bindkey -M "$keymap" '^[[4~' end-of-line
  bindkey -M "$keymap" '^[[3~' delete-char
  bindkey -M "$keymap" '^W' backward-kill-word
  bindkey -M "$keymap" '^X^E' edit-command-line
}

_archway_bind_vi() {
  bindkey -M viins '^[[Z' reverse-menu-complete
  # Command mode: undo/redo and the line-level jumps vi keeps for itself.
  bindkey -M vicmd 'u' undo
  bindkey -M vicmd '^R' redo
  bindkey -M vicmd 'v' edit-command-line
  bindkey -M vicmd 'H' beginning-of-line
  bindkey -M vicmd 'L' end-of-line
  bindkey -M vicmd '^W' backward-kill-word
}

# Block cursor in command mode, beam in insert mode, so the mode is visible
# without reading the prompt. Terminals that do not speak DECSCUSR are skipped.
_archway_cursor_shape() {
  [[ -o interactive ]] || return 0
  case $TERM in
    xterm* | screen* | tmux* | foot* | kitty* | wezterm* | alacritty* | ghostty*) ;;
    *) return 0 ;;
  esac
  case ${KEYMAP-} in
    vicmd) print -n '\e[2 q' ;;
    *) print -n '\e[6 q' ;;
  esac
}

# A vim-style mode line in the message area: visible exactly while the line
# editor is not in insert mode, and gone the moment you resume typing.
# Disable with ARCHWAY_VIM_STATUS=0.
_archway_mode_status() {
  [[ ${ARCHWAY_VIM_STATUS:-1} == 0 ]] && return 0
  case ${KEYMAP-} in
    vicmd) zle -M $'\e[7m -- NORMAL -- \e[0m' ;;
    isearch) zle -M $'\e[7m -- SEARCH -- \e[0m' ;;
    *) zle -M '' ;;
  esac
}

_archway_keymap_select() {
  _archway_cursor_shape
  _archway_mode_status
}

zle -N zle-keymap-select _archway_keymap_select

_archway_line_init() {
  _archway_cursor_shape
  zle -M ''
}

zle -N zle-line-init _archway_line_init

_archway_keymap_read() {
  local mode=${ARCHWAY_ZSH_KEYMAP-}
  if [[ -z $mode && -r $ARCHWAY_KEYMAP_FILE ]]; then
    read -r mode < "$ARCHWAY_KEYMAP_FILE" 2> /dev/null
  fi
  [[ $mode == emacs ]] && print -r -- emacs || print -r -- vi
}

typeset -g ARCHWAY_KEYMAP=$(_archway_keymap_read)

_archway_keymap_apply() {
  if [[ $1 == vi ]]; then
    KEYTIMEOUT=1
    bindkey -v
  else
    bindkey -e
  fi
  _archway_bind_common viins
  _archway_bind_common vicmd
  _archway_bind_common emacs
}

_archway_keymap_apply "$ARCHWAY_KEYMAP"
_archway_bind_vi

keymap() {
  local mode=${1:-}
  case $mode in
    vi | emacs)
      [[ -d ${ARCHWAY_KEYMAP_FILE:h} ]] || mkdir -p -- "${ARCHWAY_KEYMAP_FILE:h}"
      print -r -- "$mode" >| "$ARCHWAY_KEYMAP_FILE"
      ARCHWAY_KEYMAP=$mode
      _archway_keymap_apply "$mode"
      [[ $mode == vi ]] && _archway_bind_vi
      # Re-run atuin's init so its widgets land in the keymaps that are now
      # active. Without this, Ctrl-R would keep the previous mode's binding.
      (( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
      print -r -- "keymap: $mode"
      ;;
    '' | status)
      print -r -- "keymap: $ARCHWAY_KEYMAP"
      ;;
    *)
      print -u2 -- 'usage: keymap [vi|emacs|status]'
      return 2
      ;;
  esac
}
