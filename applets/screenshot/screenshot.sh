#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# screenshot — region/window/full capture with clipboard + file output.
set -Eeuo pipefail

DRY_RUN=0
MODE=''
OUT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"

usage() {
  cat << 'EOF'
screenshot — capture the screen on X11

Usage:
  screenshot.sh <region|window|full> [--dry-run]

Saves PNG to ~/Pictures/Screenshots and copies it to the clipboard.
Requires: maim, slop, xclip.
EOF
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "$@" || true
}

require_tools() {
  local missing=() t
  for t in maim xclip; do
    command -v "$t" > /dev/null 2>&1 || missing+=("$t")
  done
  if [[ $MODE != full ]] && ! command -v slop > /dev/null 2>&1; then
    missing+=(slop)
  fi
  if ((${#missing[@]})); then
    notify "screenshot failed" "missing: ${missing[*]}"
    printf 'screenshot: missing %s\n' "${missing[*]}" >&2
    return 3
  fi
}

capture() {
  case $MODE in
    region) maim --select --silent --format=png ;;
    window) maim --window "$(xdotool getactivewindow)" --silent --format=png ;;
    full) maim --silent --format=png ;;
    *) return 2 ;;
  esac
}

main() {
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      region | window | full) MODE=$1 ;;
      *)
        printf 'unknown argument: %s\n' "$1" >&2
        return 2
        ;;
    esac
    shift
  done

  [[ -n $MODE ]] || {
    usage
    return 2
  }
  require_tools

  local file
  file="$OUT_DIR/$(date +%Y%m%d-%H%M%S)-$MODE.png"

  if ((DRY_RUN)); then
    printf '[dry-run] mkdir -p %s\n' "$OUT_DIR"
    printf '[dry-run] capture %s -> %s\n' "$MODE" "$file"
    printf '[dry-run] xclip -selection clipboard -t image/png < %s\n' "$file"
    return 0
  fi

  mkdir -p -- "$OUT_DIR"
  if ! capture > "$file"; then
    rm -f -- "$file"
    notify "screenshot cancelled" "no image captured"
    return 1
  fi
  xclip -selection clipboard -t image/png < "$file"
  notify "screenshot saved" "$(basename -- "$file")"
  printf '%s\n' "$file"
}

main "$@"
