#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# ui.sh — human-facing presentation helpers with graceful fallbacks.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_UI_LOADED:-} ]]; then return 0; fi
ARCHWAY_UI_LOADED=1

ui_header() {
  ((QUIET)) && return 0
  printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET" >&2
  ui_rule "$((${#*} + 2))"
}

ui_rule() {
  ((QUIET)) && return 0
  local n=${1:-60} line=''
  printf -v line '%*s' "$n" ''
  printf '%s%s%s\n' "$C_DIM" "${line// /─}" "$C_RESET" >&2
}

ui_kv() {
  ((QUIET)) && return 0
  printf '  %s%-14s%s %s\n' "$C_DIM" "$1" "$C_RESET" "$2" >&2
}

ui_item() {
  ((QUIET)) && return 0
  printf '  %s•%s %s\n' "$C_BLUE" "$C_RESET" "$*" >&2
}

ui_note() {
  ((QUIET)) && return 0
  printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET" >&2
}

# ui_choose <prompt> <option...>; sets CHOICE to the selected option.
ui_choose() {
  local prompt=$1
  shift
  local -a opts=("$@")
  if ((${#opts[@]} == 0)); then
    die "ui_choose: no options" "$EX_USAGE"
  fi

  if ((ASSUME_YES)); then
    CHOICE=${opts[0]}
    return 0
  fi
  if ! [[ -t 0 && -t 2 ]]; then
    CHOICE=${opts[0]}
    return 0
  fi

  if have fzf; then
    local picked
    picked=$(printf '%s\n' "${opts[@]}" | fzf --prompt="$prompt> " --height=40% --reverse) || return 1
    CHOICE=$picked
    return 0
  fi

  printf '%s\n' "$prompt" >&2
  local i
  for i in "${!opts[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${opts[i]}" >&2
  done
  local reply
  while :; do
    printf 'choose [1-%d]: ' "${#opts[@]}" >&2
    read -r reply || return 1
    if [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#opts[@]})); then
      # shellcheck disable=SC2034 # consumed by the caller as $CHOICE
      CHOICE=${opts[reply - 1]}
      return 0
    fi
  done
}

ui_summary_list() {
  local label=$1
  shift
  (($#)) || return 0
  ui_kv "$label" "$(printf '%s, ' "$@" | sed 's/, $//')"
}
