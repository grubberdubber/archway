#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# window — window actions that need to know the current state.
#
# `maximize` is the "almost fullscreen" people actually want: the window fills
# the whole work area (monitor minus the space the bar reserved) so the bar's
# icons stay visible, instead of true fullscreen that paints over them.
#
# Hyprland 0.57 takes dispatchers as Lua expressions, and the two variants are
# not the same thing (measured on 1366x768 with a 30px bar):
#   hl.dsp.window.fullscreen({ mode = "maximized" })  -> work area, bar visible
#   hl.dsp.window.fullscreen({ mode = "fullscreen" }) -> paints over the bar
# Mode 0 (or no argument) toggles fullscreen instead of clearing, which is why
# the modes are always explicit here. `fullscreen` in `hyprctl clients` is 1
# when maximized, 2 when fullscreen and 3 when both.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ACTION=''

usage() {
  cat << 'EOF'
window — state-aware window actions for Hyprland

Usage:
  window.sh maximize        # fill the work area, keep the bar visible (toggle)
  window.sh float           # toggle floating
  window.sh center          # centre the floating window
  window.sh --status [--json]
  window.sh --dry-run <action>

Bound to Super+Shift+F (maximize) and Super+Alt+F (floating).
Needs a running Hyprland session (hyprctl) and jq.
EOF
}

die() {
  printf 'window: %s\n' "$1" >&2
  exit "${2:-1}"
}

have() { command -v "$1" > /dev/null 2>&1; }

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    --status) ACTION=status ;;
    maximize | float | center)
      ACTION=$1
      ;;
    *)
      printf 'window: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

[[ -n $ACTION ]] || {
  usage >&2
  exit 2
}

have hyprctl || die "hyprctl not found (is this a Hyprland session?)" 3
have jq || die "jq not found" 3

focused_json() {
  hyprctl clients -j 2> /dev/null |
    jq -c '[.[] | select(.focusHistoryID == 0)][0] // empty'
}

FOCUSED=$(focused_json || true)
[[ -n $FOCUSED ]] || die "no focused window" 1

ADDR=$(jq -r '.address' <<< "$FOCUSED")
CLASS=$(jq -r '.class' <<< "$FOCUSED")
FS=$(jq -r '.fullscreen' <<< "$FOCUSED")
FLOATING=$(jq -r '.floating' <<< "$FOCUSED")

if [[ $ACTION == status ]]; then
  if ((JSON)); then
    jq -n --arg a "$ADDR" --arg c "$CLASS" --argjson fs "$FS" --argjson fl "$FLOATING" \
      '{address: $a, class: $c, fullscreen: $fs, maximized: ($fs == 1 or $fs == 3), floating: ($fl == true)}'
  else
    state='normal'
    [[ $FS == 1 || $FS == 3 ]] && state='maximized'
    [[ $FS == 2 || $FS == 3 ]] && state='fullscreen'
    [[ $FLOATING == true ]] && state="floating,$state"
    printf '%s\t%s\n' "$CLASS" "$state"
  fi
  exit 0
fi

dispatch() {
  if ((DRY_RUN)); then
    printf '[dry-run] hyprctl dispatch %s\n' "$1"
    return 0
  fi
  hyprctl dispatch "$1" > /dev/null
}

case $ACTION in
  maximize)
    # `mode = "maximized"` toggles by itself and also replaces true fullscreen,
    # so this is one dispatch with no state juggling.
    dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })'
    if ((! DRY_RUN)); then
      if [[ $FS == 1 || $FS == 3 ]]; then
        printf 'unmaximised %s\n' "$CLASS" >&2
      else
        printf 'maximised %s (bar visible)\n' "$CLASS" >&2
      fi
    fi
    ;;
  float)
    dispatch 'hl.dsp.window.float({ action = "toggle" })'
    ;;
  center)
    [[ $FLOATING == true ]] || die "$CLASS is tiled; float it first (Super+Alt+F)" 1
    dispatch 'hl.dsp.window.center()'
    ;;
esac
