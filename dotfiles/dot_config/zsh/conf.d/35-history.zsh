# SPDX-License-Identifier: GPL-3.0-or-later
# History: one file under XDG state, big enough to be useful, filtered so
# credentials never reach disk, plus an on-demand transcript recorder.
#
# The filter is a safety net, not a guarantee: prefix a command with a space
# when in doubt (hist_ignore_space), and keep secrets in a password manager.

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d ${HISTFILE:h} ]] || mkdir -p -- "${HISTFILE:h}"
HISTSIZE=200000
SAVEHIST=200000
setopt hist_verify
setopt hist_find_no_dups
setopt hist_save_no_dups
setopt hist_expire_dups_first

# Cheap early exit; the zshaddhistory hook below is the real gate.
HISTIGNORE=' *'

_archway_private_command() {
  local line=$1
  # The command still runs; it just never lands in this history file or in
  # atuin (which has its own matching filter list).
  if [[ $line == *Authorization:* ||
    $line == *'PRIVATE KEY'* ||
    $line == *'BEGIN OPENSSH PRIVATE KEY'* ]] ||
    [[ $line =~ '(^|[[:space:]])--(password|passwd|token|secret|api-key|apikey|auth)(=|[[:space:]]|$)' ]] ||
    [[ $line =~ '^[[:space:]]*(export|typeset|local)[[:space:]]+[A-Za-z_]*(TOKEN|SECRET|KEY|PASSWORD|PASSWD)=' ]]; then
    return 1
  fi
  return 0
}

autoload -Uz add-zsh-hook
add-zsh-hook zshaddhistory _archway_private_command

typeset -g ARCHWAY_SESSION_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway/sessions"

# Start a timestamped transcript for an audit, a lab session or a debugging
# run. It opens a nested login shell; `exit` or Ctrl-D stops the recording.
rec() {
  local dir=${1:-$ARCHWAY_SESSION_DIR} stamp file
  if (( ! $+commands[script] )); then
    print -u2 -- "rec: util-linux 'script' is required"
    return 1
  fi
  mkdir -p -- "$dir" || return 1
  stamp=$(date +%Y%m%dT%H%M%S) || return 1
  file="$dir/session-$stamp.log"
  print -r -- "recording → $file"
  print -r -- "a nested shell starts; type 'exit' or Ctrl-D to stop"
  script --quiet --flush --return --command "${SHELL:-/bin/zsh} -l" "$file"
}

rec-ls() {
  local files=("${ARCHWAY_SESSION_DIR}"/session-*.log(Nom))
  if (( ! $#files )); then
    print -r -- 'rec-ls: no transcripts yet'
    return 0
  fi
  print -l -- "${files[@]}"
}
