#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# osd — volume, microphone and brightness keys with a small on-screen display.
#
# Preferred backend: swayosd (official `extra` package). Its window is styled by
# ~/.config/swayosd/style.css from the active theme, so the OSD matches the bar
# instead of raising a full-width notification. Without swayosd the script falls
# back to pamixer/brightnessctl + notify-send, which still works everywhere.
set -Eeuo pipefail

DRY_RUN=0

usage() {
  cat << 'EOF'
osd — volume, microphone and brightness control with an OSD

Usage:
  osd.sh volume <up|down|mute>
  osd.sh mic <mute>
  osd.sh brightness <up|down>
  osd.sh capslock

Backend: swayosd-client when installed, otherwise pamixer/brightnessctl plus a
short notification. Never touches audio routing or the mixer itself.
EOF
}

die() {
  printf 'osd: %s\n' "$1" >&2
  exit "${2:-1}"
}

have() { command -v "$1" > /dev/null 2>&1; }

notify() {
  have notify-send || return 0
  notify-send -a Archway -t 900 -h string:x-canonical-private-synchronous:archway-osd "$@" > /dev/null 2>&1 || true
}

notify_value() {
  local title=$1 value=$2
  have notify-send || return 0
  notify-send -a Archway -t 900 \
    -h string:x-canonical-private-synchronous:archway-osd \
    -h "int:value:$value" "$title" "${value}%" > /dev/null 2>&1 || true
}

run() {
  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

volume() {
  local action=$1
  if have swayosd-client; then
    case $action in
      up) run swayosd-client --output-volume raise ;;
      down) run swayosd-client --output-volume lower ;;
      mute) run swayosd-client --output-volume mute-toggle ;;
      *) die "volume: expected up, down or mute" 2 ;;
    esac
    return 0
  fi

  have pamixer || die "pamixer is required without swayosd" 3
  case $action in
    up)
      run pamixer -i 5 --allow-boost
      ((DRY_RUN)) || notify_value volume "$(pamixer --get-volume)"
      ;;
    down)
      run pamixer -d 5
      ((DRY_RUN)) || notify_value volume "$(pamixer --get-volume)"
      ;;
    mute)
      run pamixer -t
      ((DRY_RUN)) || {
        if [[ $(pamixer --get-mute) == true ]]; then
          notify volume muted
        else
          notify_value volume "$(pamixer --get-volume)"
        fi
      }
      ;;
    *) die "volume: expected up, down or mute" 2 ;;
  esac
}

mic() {
  local action=${1:-mute}
  [[ $action == mute ]] || die "mic: only 'mute' is supported" 2
  if have swayosd-client; then
    run swayosd-client --input-volume mute-toggle
    return 0
  fi
  have pamixer || die "pamixer is required without swayosd" 3
  run pamixer --default-source -t
  ((DRY_RUN)) || {
    if [[ $(pamixer --default-source --get-mute) == true ]]; then
      notify microphone muted
    else
      notify microphone on
    fi
  }
}

brightness() {
  local action=$1
  if have swayosd-client; then
    case $action in
      up) run swayosd-client --brightness raise ;;
      down) run swayosd-client --brightness lower ;;
      *) die "brightness: expected up or down" 2 ;;
    esac
    return 0
  fi
  have brightnessctl || die "brightnessctl is required without swayosd" 3
  case $action in
    up) run brightnessctl -q set 5%+ ;;
    down) run brightnessctl -q set 5%- ;;
    *) die "brightness: expected up or down" 2 ;;
  esac
  ((DRY_RUN)) || notify_value brightness "$(brightnessctl -m | awk -F, '{ gsub(/%/, "", $4); print $4 }')"
}

capslock() {
  have swayosd-client || die "capslock OSD needs swayosd" 3
  run swayosd-client --caps-lock
}

main() {
  local -a args=()
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      -*)
        usage >&2
        die "unknown option: $1" 2
        ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  ((${#args[@]})) || {
    usage >&2
    exit 2
  }

  case ${args[0]} in
    volume) volume "${args[1]:-}" ;;
    mic) mic "${args[1]:-mute}" ;;
    brightness) brightness "${args[1]:-}" ;;
    capslock) capslock ;;
    *)
      usage >&2
      die "unknown action: ${args[0]}" 2
      ;;
  esac
}

main "$@"
