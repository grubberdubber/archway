#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# color-picker — pick a pixel from the screen, copy its hex, show the swatch.
#
# Two backends, same result:
#   hyprpicker   the zoom lens of Hyprland's picker, the one the keybind uses.
#   grim+slurp   a 1x1 grab at the crosshair, for a session without hyprpicker.
# The colour is copied once, by this script, instead of letting hyprpicker copy
# and then copying again: two writes per pick would show up twice in cliphist.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
COPY=1
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/archway"

usage() {
  cat << 'EOF'
color-picker — copy the colour of any pixel (Super+Alt+C)

Usage:
  color-picker.sh [pick] [--dry-run] [--json] [--no-copy]
  color-picker.sh --help

  pick       pick a pixel, copy it as #RRGGBB and show a notification with a
             swatch of the colour. This is the default.
  --no-copy  pick and print, but leave the clipboard alone (no notification).
  --json     print {"hex","rgb","backend"} instead of the hex code.
  --dry-run  say which backend would run; touch nothing.

Backends, in order: hyprpicker (zoom lens over the pixel), then grim + slurp
(crosshair, 1x1 grab). hyprpicker is the one that magnifies; without it the
crosshair still lands on an exact pixel, it just does not show a preview.
Requires wl-clipboard to copy and a notification daemon; ImageMagick draws the
swatch. Exit codes: 0 ok, 1 error, 2 usage, 4 cancelled.
EOF
}

have() { command -v "$1" > /dev/null 2>&1; }

die() {
  printf 'color-picker: %s\n' "$1" >&2
  exit "${2:-1}"
}

parse_args() {
  local arg
  for arg in "$@"; do
    case $arg in
      pick) ;;
      --dry-run) DRY_RUN=1 ;;
      --json) JSON=1 ;;
      --no-copy) COPY=0 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        printf 'color-picker: unknown option: %s\n' "$arg" >&2
        exit 2
        ;;
    esac
  done
}

backend() {
  if have hyprpicker; then
    printf 'hyprpicker'
  elif have grim && have slurp; then
    printf 'grim'
  elif have xcolor; then
    printf 'xcolor'
  else
    printf 'none'
  fi
}

# #rgb, #rrggbb and bare rrggbb all end up as #RRGGBB; anything else is a
# backend failure, not a colour.
normalise_hex() {
  local raw=${1,,} out=''
  raw=${raw//[[:space:]]/}
  raw=${raw#\#}
  case ${#raw} in
    3) out="${raw:0:1}${raw:0:1}${raw:1:1}${raw:1:1}${raw:2:1}${raw:2:1}" ;;
    6) out=$raw ;;
    *) return 1 ;;
  esac
  [[ $out =~ ^[0-9a-f]{6}$ ]] || return 1
  printf '#%s' "${out^^}"
}

pick_hyprpicker() {
  # -s 6 keeps the lens readable on a 1366-wide panel without covering the
  # pixel underneath; -q silences the log, the colour is the only output.
  local raw
  raw=$(hyprpicker -f hex -s 6 -q 2> /dev/null) || return 1
  # No output means the pick was cancelled; output that is not a colour means
  # the backend is broken. They are different exit codes, not one failure.
  [[ -n ${raw//[[:space:]]/} ]] || return 4
  normalise_hex "$raw" || return 1
}

pick_grim() {
  local point x y png
  point=$(slurp -p) || return 4
  # slurp -p prints "x,y" for a single point; refuse anything else instead of
  # handing a half-parsed geometry to grim.
  [[ $point =~ ^([0-9]+),([0-9]+)$ ]] || return 1
  x=${BASH_REMATCH[1]}
  y=${BASH_REMATCH[2]}
  png=$(grim -g "${x},${y} 1x1" - 2> /dev/null) || return 1
  [[ -n $png ]] || return 1
  have magick || return 1
  normalise_hex "$(printf '%s' "$png" | magick png:- -format '%[hex:p{0,0}]' info: 2> /dev/null)" || return 1
}

pick_xcolor() {
  # xcolor is the X11 equivalent: -S is the lens size, -P the zoom.
  normalise_hex "$(xcolor -S 10 -P 150 2> /dev/null)" || return 1
}

rgb_of() {
  local hex=${1#\#}
  printf '%d %d %d\n' "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

swatch() {
  local hex=$1 file=$RUNTIME_DIR/color.png
  have magick || return 0
  mkdir -p -- "$RUNTIME_DIR"
  magick -size 96x96 "xc:${hex}" "png:${file}" 2> /dev/null || return 0
  # Only advertise a swatch that really exists: a broken image path in the
  # hint is worse than a plain text notification.
  [[ -f $file ]] || return 0
  printf '%s' "$file"
}

notify() {
  local hex=$1 image=$2 text r g b
  read -r r g b < <(rgb_of "$hex")
  text="$hex  ·  rgb($r, $g, $b)"
  if have notify-send; then
    if [[ -n $image ]]; then
      notify-send -a Archway -i "$image" -h "string:image-path:$image" \
        -h "string:x-canonical-private-synchronous:archway-color" \
        "Colour copied" "$text" > /dev/null 2>&1 && return 0
    fi
    notify-send -a Archway -h "string:x-canonical-private-synchronous:archway-color" \
      "Colour copied" "$text" > /dev/null 2>&1 && return 0
  fi
  if have dunstify; then
    dunstify -a Archway -i "${image:-dialog-information}" \
      -h "string:x-dunst-stack-tag:archway-color" "Colour copied" "$text" > /dev/null 2>&1 || true
  fi
  return 0
}

main() {
  parse_args "$@"

  local be hex image
  be=$(backend)
  if [[ $be == none ]]; then
    die "no colour picker available: install hyprpicker (or grim, slurp and imagemagick)" 1
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] backend: %s; copy: %s\n' "$be" "$([[ $COPY == 1 ]] && echo yes || echo no)"
    return 0
  fi

  local rc=0
  case $be in
    hyprpicker) hex=$(pick_hyprpicker) || rc=$? ;;
    grim) hex=$(pick_grim) || rc=$? ;;
    xcolor) hex=$(pick_xcolor) || rc=$? ;;
  esac
  if [[ -z ${hex:-} ]]; then
    if ((rc == 4)); then
      die "no colour picked" 4
    fi
    die "could not read a colour from ${be}" 1
  fi

  if ((COPY)); then
    if have wl-copy; then
      printf '%s' "$hex" | wl-copy > /dev/null 2>&1 || die "could not write to the clipboard" 1
    elif have xclip; then
      printf '%s' "$hex" | xclip -selection clipboard > /dev/null 2>&1 || die "could not write to the clipboard" 1
    else
      die "no clipboard tool: install wl-clipboard" 1
    fi
    image=$(swatch "$hex")
    notify "$hex" "$image"
  fi

  if ((JSON)); then
    local r g b
    read -r r g b < <(rgb_of "$hex")
    printf '{"hex":"%s","rgb":{"r":%d,"g":%d,"b":%d},"backend":"%s"}\n' "$hex" "$r" "$g" "$b" "$be"
  else
    printf '%s\n' "$hex"
  fi
}

main "$@"
