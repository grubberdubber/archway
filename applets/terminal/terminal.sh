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
MODE=run
SET_TO=''
# Inside the middle band no side is forced: spawn as usual.
DEAD_ZONE=15 # percent of half the area width/height
TIMEOUT=30   # tenths of a second to wait for the new window

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/archway"
TERMINAL_FILE="$CONFIG_DIR/terminal"
# Terminals Archway knows how to launch; --pick only offers the installed ones.
KNOWN_TERMINALS=(kitty alacritty ghostty wezterm foot)

usage() {
  cat << 'EOF'
terminal — open a terminal on the side of the workspace the cursor is on

Usage:
  terminal.sh [--dry-run] [--json]     open a terminal towards the cursor
  terminal.sh --print                  print the default terminal
  terminal.sh --set <command>          make <command> the default terminal
  terminal.sh --pick                   choose the default terminal with rofi

The pointer picks the side: left, right, up or down from the centre of the
workspace work area (monitor minus reserved space, so the bar is excluded).
With the pointer in the middle band the terminal opens the way dwindle decides.
--dry-run and --json only report the decision; they start nothing.

Default: $ARCHWAY_TERMINAL if set, else $XDG_CONFIG_HOME/archway/terminal,
else kitty. `--set` writes that file (user config, never the repo).

Needs a running Hyprland session (hyprctl) and jq.
EOF
}

die() {
  printf 'terminal: %s\n' "$1" >&2
  exit "${2:-1}"
}

have() { command -v "$1" > /dev/null 2>&1; }

# Resolution order: environment, then the per-host file, then kitty. The file is
# what `--set`/`--pick` write, so a preference survives sessions without a
# rebuild and without touching the repo.
default_terminal() {
  local saved=''
  if [[ -n ${ARCHWAY_TERMINAL:-} ]]; then
    printf '%s' "$ARCHWAY_TERMINAL"
    return
  fi
  if [[ -r $TERMINAL_FILE ]]; then
    IFS= read -r saved < "$TERMINAL_FILE" || true
    if [[ -n $saved ]]; then
      printf '%s' "$saved"
      return
    fi
  fi
  printf 'kitty'
}

# The command may carry arguments ("kitty --single-instance"); only the program
# has to exist.
program_of() { printf '%s' "${1%% *}"; }

set_terminal() {
  local cmd=$1 program
  program=$(program_of "$cmd")
  have "$program" || die "'$program' is not installed" 3
  if ((DRY_RUN)); then
    printf '[dry-run] write %s -> %s\n' "$TERMINAL_FILE" "$cmd"
    return 0
  fi
  mkdir -p -- "$CONFIG_DIR"
  printf '%s\n' "$cmd" > "$TERMINAL_FILE"
  chmod 644 -- "$TERMINAL_FILE"
  printf 'default terminal: %s\n' "$cmd"
}

pick_terminal() {
  have rofi || die "rofi is required for --pick" 3
  local t current choice
  current=$(default_terminal)
  local -a rows=()
  for t in "${KNOWN_TERMINALS[@]}"; do
    have "$t" || continue
    if [[ $t == "$(program_of "$current")" ]]; then
      rows+=("* $t")
    else
      rows+=("$t")
    fi
  done
  ((${#rows[@]})) || die "no supported terminal is installed" 3
  choice=$(printf '%s\n' "${rows[@]}" |
    rofi -dmenu -i -p terminal -theme "$CONFIG_DIR/theme.d/rofi.rasi") || return 1
  [[ -n $choice ]] || return 1
  set_terminal "${choice#\* }"
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    --print) MODE=print ;;
    --pick) MODE=pick ;;
    --set)
      MODE='set'
      SET_TO=${2:-}
      [[ -n $SET_TO ]] || die "--set needs a command" 2
      shift
      ;;
    *)
      printf 'terminal: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

case $MODE in
  print)
    default_terminal
    printf '\n'
    exit 0
    ;;
  set)
    set_terminal "$SET_TO"
    exit 0
    ;;
  pick)
    pick_terminal
    exit 0
    ;;
esac

# The program is only required when something is actually started; --dry-run and
# --json must work on a machine without any terminal installed (CI containers).
TERMINAL=$(default_terminal)
TERMINAL_PROGRAM=$(program_of "$TERMINAL")

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
  jq -n --arg d "$direction" --arg t "$TERMINAL" --argjson x "$CX" --argjson y "$CY" \
    --argjson area "[$AX, $AY, $AW, $AH]" '{direction: $d, terminal: $t, cursor: [$x, $y], area: $area}'
  exit 0
fi
if ((DRY_RUN)); then
  printf '[dry-run] %s: cursor (%s,%s) in %sx%s at %s,%s\n' \
    "${direction:-centre}" "$CX" "$CY" "$AW" "$AH" "$AX" "$AY"
  printf '[dry-run] %s &\n' "$TERMINAL"
  exit 0
fi

# ----------------------------------------------------------------- spawn ---

have "$TERMINAL_PROGRAM" || die "default terminal '$TERMINAL_PROGRAM' is not installed (archway applet terminal --pick)" 3

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
