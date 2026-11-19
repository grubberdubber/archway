#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# screenshot — region/window/full capture with clipboard + file output.
# Wayland-native: grim captures, slurp selects, wl-copy puts it on the clipboard.
set -Eeuo pipefail

DRY_RUN=0
MODE=''
OUT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"

usage() {
  cat << 'EOF'
screenshot — capture the screen on Wayland

Usage:
  screenshot.sh <region|window|full> [--dry-run]

Saves PNG to ~/Pictures/Screenshots and copies it to the clipboard.
Requires: grim, wl-clipboard; slurp for region and hyprctl+jq for window.
EOF
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "$@" || true
}

require_tools() {
  local missing=() t
  for t in grim wl-copy; do
    command -v "$t" > /dev/null 2>&1 || missing+=("$t")
  done
  case $MODE in
    region)
      command -v slurp > /dev/null 2>&1 || missing+=(slurp)
      ;;
    window)
      command -v hyprctl > /dev/null 2>&1 || missing+=(hyprctl)
      command -v jq > /dev/null 2>&1 || missing+=(jq)
      ;;
  esac
  if ((${#missing[@]})); then
    notify "screenshot failed" "missing: ${missing[*]}"
    printf 'screenshot: missing %s\n' "${missing[*]}" >&2
    return 3
  fi
}

# Geometry of the focused window as "x,y wxh" for `grim -g`.
window_geometry() {
  hyprctl -j activewindow | jq -r '
    "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
  ' 2> /dev/null
}

capture() {
  case $MODE in
    region)
      local geometry
      geometry=$(slurp) || return 1
      [[ -n $geometry ]] || return 1
      grim -g "$geometry" -
      ;;
    window)
      local geometry
      geometry=$(window_geometry) || return 1
      [[ -n $geometry && $geometry != "null,null nullxnull" ]] || return 1
      grim -g "$geometry" -
      ;;
    full) grim - ;;
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
    printf '[dry-run] wl-copy --type image/png < %s\n' "$file"
    return 0
  fi

  mkdir -p -- "$OUT_DIR"
  if ! capture > "$file"; then
    rm -f -- "$file"
    notify "screenshot cancelled" "no image captured"
    return 1
  fi
  wl-copy --type image/png < "$file"
  notify "screenshot saved" "$(basename -- "$file")"
  printf '%s\n' "$file"
}

main "$@"
