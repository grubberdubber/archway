#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# power — session menu. Nothing destructive happens without confirmation.
set -Eeuo pipefail

DRY_RUN=0
ROFI=0

usage() {
  cat << 'EOF'
power — Archway session menu

Usage:
  power.sh [--rofi] [--dry-run]
  power.sh --action <lock|logout|suspend|reboot|poweroff>

Actions: lock (hyprlock), logout (uwsm/Hyprland), suspend, reboot, poweroff.
Every destructive action asks for confirmation unless it came from the menu
(which shows the exact command before running it).
EOF
}

notify() {
  if command -v notify-send > /dev/null 2>&1; then
    notify-send -a Archway "${1:-power}" "${2:-}"
  fi
}

confirm() {
  if [[ ! -t 0 ]]; then return 0; fi
  local reply
  printf '%s [y/N] ' "$1" >&2
  read -r reply
  [[ $reply =~ ^[yY]([eE][sS])?$ ]]
}

run_action() {
  local action=$1
  case $action in
    lock)
      command -v hyprlock > /dev/null 2>&1 || {
        notify "lock unavailable" "install hyprlock"
        return 1
      }
      [[ $DRY_RUN == 1 ]] && {
        echo "[dry-run] hyprlock"
        return 0
      }
      exec hyprlock
      ;;
    logout)
      [[ $DRY_RUN == 1 ]] && {
        echo "[dry-run] uwsm stop || hyprctl dispatch exit"
        return 0
      }
      if command -v uwsm > /dev/null 2>&1; then
        exec uwsm stop
      fi
      exec hyprctl dispatch exit
      ;;
    suspend | reboot | poweroff)
      local verb=$action
      [[ $action == poweroff ]] && verb=poweroff
      if [[ $ROFI == 1 ]] || confirm "Really $action now?"; then
        [[ $DRY_RUN == 1 ]] && {
          echo "[dry-run] systemctl $verb"
          return 0
        }
        exec systemctl "$verb"
      fi
      notify "cancelled" "$action cancelled"
      ;;
    *)
      printf 'unknown action: %s\n' "$action" >&2
      return 2
      ;;
  esac
}

menu() {
  command -v rofi > /dev/null 2>&1 || {
    usage
    return 1
  }
  local choice
  choice=$(printf '%s\n' \
    "lock        hyprlock" \
    "logout      uwsm stop" \
    "suspend     systemctl suspend" \
    "reboot      systemctl reboot" \
    "poweroff    systemctl poweroff" |
    rofi -dmenu -p power -theme "$HOME/.config/archway/theme.d/rofi.rasi") || return 1
  [[ -n $choice ]] || return 1
  run_action "${choice%% *}"
}

main() {
  local action=''
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      --rofi) ROFI=1 ;;
      --action)
        action=${2:-}
        shift
        ;;
      *)
        printf 'unknown argument: %s\n' "$1" >&2
        return 2
        ;;
    esac
    shift
  done

  if ((EUID == 0)); then
    printf 'power: run as your user, not root\n' >&2
    return 2
  fi

  if [[ -n $action ]]; then
    run_action "$action"
  elif ((ROFI)); then
    menu
  else
    usage
  fi
}

main "$@"
