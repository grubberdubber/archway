#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# clipboard — cliphist history picker.
#
# cliphist only records what `wl-paste --watch` feeds it. Without a running
# watcher Super+V opened an empty menu forever, which reads as "broken"; this
# script starts the watcher when it is missing and then shows the picker.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
MODE=pick
ARG=''

usage() {
  cat << 'EOF'
clipboard — clipboard history (cliphist + rofi)

Usage:
  clipboard.sh [pick] [--rofi]
  clipboard.sh --list [--json]
  clipboard.sh --clear
  clipboard.sh --delete <id>

The history lives in cliphist's database under ~/.local/state. Passwords copied
from a password manager should be cleared with --clear.
EOF
}

die() {
  printf 'clipboard: %s\n' "$1" >&2
  notify "clipboard" "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "$@" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

require_tools() {
  local missing=() t
  for t in cliphist wl-copy wl-paste; do
    have "$t" || missing+=("$t")
  done
  ((${#missing[@]} == 0)) || die "missing ${missing[*]} (pacman -S cliphist wl-clipboard)" 3
}

watcher_running() {
  pgrep -f "wl-paste .*--watch cliphist store" > /dev/null 2>&1
}

ensure_watcher() {
  watcher_running && return 0
  ((DRY_RUN)) && {
    printf '[dry-run] start wl-paste watchers for cliphist\n'
    return 0
  }
  # Both text and images are stored; each needs its own wl-paste process.
  setsid wl-paste --type text --watch cliphist store > /dev/null 2>&1 &
  setsid wl-paste --type image --watch cliphist store > /dev/null 2>&1 &
  # Give the watchers a moment so the first Super+V already sees new entries.
  local _
  for _ in 1 2 3 4 5; do
    watcher_running && return 0
    sleep 0.1
  done
  return 0
}

history_lines() {
  cliphist list 2> /dev/null || true
}

pick() {
  ensure_watcher
  have rofi || die "rofi is required for the picker" 3
  local lines choice
  lines=$(history_lines)
  if [[ -z $lines ]]; then
    die "clipboard history is empty — copy something first"
  fi
  choice=$(printf '%s\n' "$lines" |
    rofi -dmenu -i -display-columns 2 -p clipboard \
      -theme "$HOME/.config/archway/theme.d/rofi.rasi") || return 1
  [[ -n $choice ]] || return 1
  if ((DRY_RUN)); then
    printf '[dry-run] cliphist decode <<< %s | wl-copy\n' "${choice%%$'\t'*}"
    return 0
  fi
  printf '%s\n' "$choice" | cliphist decode 2> /dev/null | wl-copy
}

main() {
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      --json) JSON=1 ;;
      --rofi) MODE=pick ;;
      --list) MODE=list ;;
      --clear) MODE=clear ;;
      --delete)
        MODE=delete
        ARG=${2:-}
        [[ -n $ARG ]] || die "--delete needs an id" 2
        shift
        ;;
      pick) MODE=pick ;;
      *)
        usage >&2
        die "unknown argument: $1" 2
        ;;
    esac
    shift
  done

  require_tools
  case $MODE in
    list)
      if ((JSON)); then
        local count=0 id
        while IFS=$'\t' read -r id _; do
          [[ -n $id ]] && count=$((count + 1))
        done < <(history_lines)
        printf '{"entries":%d,"watcher":%s}\n' "$count" \
          "$(watcher_running && printf true || printf false)"
      else
        history_lines
      fi
      ;;
    clear)
      if ((DRY_RUN)); then
        printf '[dry-run] cliphist wipe\n'
      else
        cliphist wipe
        notify "clipboard" "history cleared"
      fi
      ;;
    delete)
      if ((DRY_RUN)); then
        printf '[dry-run] cliphist delete <<< %s\n' "$ARG"
      else
        printf '%s\n' "$ARG" | cliphist delete
      fi
      ;;
    pick) pick ;;
  esac
}

main "$@"
