#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# terminal — open a terminal on the side of the workspace the cursor points at.
#
# dwindle already splits towards the pointer, but it measures the offset against
# the focused window: with two terminals side by side and the pointer at the
# bottom of the screen the offset is mostly horizontal, so the new terminal opens
# as a thin column at the side instead of a rectangle at the bottom. This applet
# reads the pointer against the workspace work area first and corrects the
# placement once when dwindle guessed another side.
#
# Bound to Super+Return. `kitty --class floating-term` (scratchpad) and the other
# terminals are launched directly and are not affected.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
# Inside the middle band no side is forced: spawn as usual.
DEAD_ZONE=15 # percent of half the area width/height
TIMEOUT=30   # tenths of a second to wait for the new window
TERMINAL="${ARCHWAY_TERMINAL:-kitty}"

usage() {
  cat << 'EOF'
terminal — open a terminal on the side of the workspace the cursor is on

Usage:
  terminal.sh [--dry-run] [--json]

The pointer picks the side: left, right, up or down from the centre of the
workspace work area (monitor minus reserved space, so the bar is excluded).
With the pointer in the middle band the terminal opens the way dwindle decides.
--dry-run and --json only report the decision; they start nothing.

Environment:
  ARCHWAY_TERMINAL   command to run (default: kitty)

Needs a running Hyprland session (hyprctl) and jq.
EOF
}

die() {
  printf 'terminal: %s\n' "$1" >&2
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
    *)
      printf 'terminal: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

# ---------------------------------------------------------------- pointer ---

have hyprctl || die "hyprctl not found (is this a Hyprland session?)" 3
have jq || die "jq not found" 3

# Work area of the focused monitor: its rectangle minus the space the bar and
# other exclusive zones reserved, so "down" means down over the usable screen.
AX='' AY='' AW='' AH=''
read -r AX AY AW AH < <(
  hyprctl monitors -j |
    jq -r '([.[] | select(.focused == true)][0] // .[0])
      | "\(.x + (.reserved[0] // 0)) \(.y + (.reserved[1] // 0)) "
      + "\(.width - (.reserved[0] // 0) - (.reserved[2] // 0)) "
      + "\(.height - (.reserved[1] // 0) - (.reserved[3] // 0))"'
) || true
[[ -n ${AX:-} && $AW -gt 0 && $AH -gt 0 ]] || die "cannot read the monitor geometry" 3

CURSOR=$(hyprctl cursorpos)
CX=${CURSOR%%,*}
CY=${CURSOR#*,}
CX=${CX//[!0-9-]/}
CY=${CY//[!0-9-]/}
[[ -n $CX && -n $CY ]] || die "cannot read the cursor position" 3

# Offset of the pointer from the centre, normalised to -100..100 on each axis so
# a wide screen does not always win: the largest *relative* offset picks the side.
NX=$(((CX - (AX + AW / 2)) * 100 / (AW / 2)))
NY=$(((CY - (AY + AH / 2)) * 100 / (AH / 2)))

direction=''
if ((${NX#-} >= DEAD_ZONE || ${NY#-} >= DEAD_ZONE)); then
  if ((${NX#-} >= ${NY#-})); then
    ((NX > 0)) && direction='right' || direction='left'
  else
    ((NY > 0)) && direction='down' || direction='up'
  fi
fi

# Both --json and --dry-run are reports: they never start a terminal.
if ((JSON)); then
  jq -n --arg d "$direction" --argjson x "$CX" --argjson y "$CY" \
    --argjson area "[$AX, $AY, $AW, $AH]" '{direction: $d, cursor: [$x, $y], area: $area}'
  exit 0
fi
if ((DRY_RUN)); then
  printf '[dry-run] %s: cursor (%s,%s) in %sx%s at %s,%s\n' \
    "${direction:-centre}" "$CX" "$CY" "$AW" "$AH" "$AX" "$AY"
  printf '[dry-run] %s &\n' "$TERMINAL"
  exit 0
fi

# ----------------------------------------------------------------- spawn ---

# The window map is compared by pid: the terminal we started is the one to look
# at, even when another window opens at the same time.
read -r -a BEFORE <<< "$(hyprctl clients -j | jq -r '[.[].pid] | join(" ")' || true)"

# shellcheck disable=SC2086
setsid $TERMINAL > /dev/null 2>&1 &
PID=$!

ADDR=''
for _ in $(seq "$TIMEOUT"); do
  sleep 0.1
  ADDR=$(hyprctl clients -j |
    jq -r --argjson pid "$PID" '.[] | select(.pid == $pid) | .address' | head -1 || true)
  [[ -n $ADDR ]] && break
done

# A slow start or a wrapper script means no pid match; fall back to the first
# window that was not there before, and never block the terminal on this.
if [[ -z $ADDR ]]; then
  ADDR=$(hyprctl clients -j |
    jq -r --arg known "${BEFORE[*]}" '
      ($known | split(" ") | map(tonumber)) as $before
      | [.[] | select(.pid as $p | $before | index($p) | not)][0].address // empty' || true)
fi

if [[ -z $ADDR || -z $direction ]]; then
  exit 0
fi

# --------------------------------------------------------------- correct ---

WX='' WY='' WW='' WH=''
read -r WX WY WW WH < <(
  hyprctl clients -j |
    jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'
) || true
[[ -n ${WX:-} ]] || exit 0

MID_X=$((AX + AW / 2))
MID_Y=$((AY + AH / 2))
SLACK=8 # gaps and rounding must not turn a correct placement into a wrong one

placed=1
case $direction in
  left) ((WX + WW <= MID_X + SLACK)) && placed=0 ;;
  right) ((WX >= MID_X - SLACK)) && placed=0 ;;
  up) ((WY + WH <= MID_Y + SLACK)) && placed=0 ;;
  down) ((WY >= MID_Y - SLACK)) && placed=0 ;;
esac

if ((placed == 1)); then
  # One nudge only: dwindle re-inserts the window on that side, and repeating it
  # would keep shuffling a layout the user may already be reading.
  hyprctl dispatch "hl.dsp.window.move({ direction = \"$direction\" })" > /dev/null 2>&1 || true
fi
