#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bluetooth — bluetoothctl menu in rofi (Super+Shift+B).
#
# blueman is a GTK app that looks nothing like the rest of the desktop and pulls
# a tray icon nobody asked for; this menu lists paired/known devices, connects,
# disconnects and toggles the adapter with two keystrokes. No root, no daemon of
# its own: it drives the system BlueZ over D-Bus through bluetoothctl.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ROFI=0
ACTION='status'
WANT=''

usage() {
  cat << 'EOF'
bluetooth — adapter and device menu

Usage:
  bluetooth.sh [status] [--json]
  bluetooth.sh --rofi              # interactive menu (Super+Shift+B)
  bluetooth.sh --power on|off|toggle
  bluetooth.sh --connect <MAC>

status   adapter power and the connected devices.
--rofi   menu: toggle the adapter, scan, connect or disconnect a device.

Requires bluez and bluez-utils (bluetoothctl); the menu needs rofi.
Devices are never forgotten or removed from here: forgetting a pairing is a
destructive action that belongs in `bluetoothctl remove` with a human watching.
EOF
}

die() {
  printf 'bluetooth: %s\n' "$1" >&2
  notify "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "bluetooth" "$1" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

require_bt() {
  have bluetoothctl || die "bluetoothctl not found (pacman -S bluez bluez-utils)" 3
}

run() {
  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# Read the whole reply first: piping bluetoothctl into an early-exiting awk
# raises SIGPIPE for bluetoothctl, and `pipefail` would turn a successful read
# into a 141 exit code that kills the applet under `set -e`.
power_state() {
  local out
  out=$(bluetoothctl show 2> /dev/null || true)
  awk -F': ' '/^[[:space:]]*Powered:/ { print $2; exit }' <<< "$out"
}

powered() { [[ $(power_state) == yes ]]; }

# "AA:BB:CC:DD:EE:FF<TAB>Device name", one per line.
device_rows() {
  local out
  out=$(bluetoothctl devices 2> /dev/null || true)
  awk '/^Device / { mac = $2; $1 = ""; $2 = ""; sub(/^[ \t]+/, ""); if (mac != "") print mac "\t" $0 }' <<< "$out"
}

# Captured, not piped into grep -q: under `pipefail` an early grep exit makes
# bluetoothctl die of SIGPIPE and the match would read as a failure.
device_info() { bluetoothctl info "$1" 2> /dev/null || true; }

is_connected() { [[ $(device_info "$1") == *"Connected: yes"* ]]; }

connected_devices() {
  local mac name
  while IFS=$'\t' read -r mac name; do
    [[ -n $mac ]] || continue
    is_connected "$mac" && printf '%s\n' "$name"
  done <<< "$(device_rows)"
}

status_text() {
  local state connected
  state=$(power_state || true)
  printf 'bluetooth: %s\n' "${state:-unknown}"
  connected=$(connected_devices || true)
  if [[ -n $connected ]]; then
    while IFS= read -r name; do printf '  %s\n' "$name"; done <<< "$connected"
  fi
}

json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

status_json() {
  local state list pairs='' sep='' name
  state=$(power_state || true)
  list=$(connected_devices || true)
  if [[ -n $list ]]; then
    while IFS= read -r name; do
      [[ -n $name ]] || continue
      pairs+="$sep$(json_str "$name")"
      sep=','
    done <<< "$list"
  fi
  printf '{"powered":%s,"state":%s,"connected":[%s]}\n' \
    "$([[ $state == yes ]] && echo true || echo false)" "$(json_str "${state:-unknown}")" "$pairs"
}

set_power() {
  local want=$1
  [[ $want == toggle ]] && { if powered; then want=off; else want=on; fi; }
  case $want in
    on | off) ;;
    *) die "power: expected on, off or toggle" 2 ;;
  esac
  if ((DRY_RUN)); then
    printf '[dry-run] bluetoothctl power %s\n' "$want"
    return 0
  fi
  bluetoothctl power "$want" > /dev/null || die "could not power the adapter $want"
  ((DRY_RUN)) && return 0
  notify "adapter $([[ $(power_state) == yes ]] && echo on || echo off)"
}

connect_mac() {
  local mac=$1
  [[ -n $mac ]] || die "connect: empty address" 2
  if ((DRY_RUN)); then
    printf '[dry-run] bluetoothctl connect %s\n' "$mac"
    return 0
  fi
  local out
  out=$(bluetoothctl connect "$mac" 2>&1 || true)
  if [[ $out == *"Connection successful"* ]]; then
    notify "connected to $mac"
  else
    die "could not connect to $mac (out of range, or not paired yet)"
  fi
}

bt_menu() {
  have rofi || die "rofi is required for the menu" 3
  local choice action arg rows mac name marker
  while true; do
    if powered; then
      local menu
      menu=$(printf 'power\t\tTurn Bluetooth off\nscan\t\tScan for devices\nsettings\t\tBluetooth settings')
      rows=$(device_rows)
      if [[ -n $rows ]]; then
        while IFS=$'\t' read -r mac name; do
          [[ -n $mac ]] || continue
          marker=' '
          is_connected "$mac" && marker='*'
          menu+=$(printf '\ndevice\t%s\t%s %s' "$mac" "$marker" "$name")
        done <<< "$rows"
      fi
    else
      menu=$(printf 'power\t\tTurn Bluetooth on')
    fi

    choice=$(printf '%s\n' "$menu" |
      rofi -dmenu -i -p bluetooth -display-columns 3 -format s \
        -theme "${XDG_CONFIG_HOME:-$HOME/.config}/archway/theme.d/rofi.rasi") || return 0
    [[ -n $choice ]] || return 0

    IFS=$'\t' read -r action arg _ <<< "$choice"
    case $action in
      power) set_power toggle ;;
      scan)
        # A timed scan keeps Bluetoothctl from holding the adapter forever.
        run timeout 10 bluetoothctl --timeout 8 scan on > /dev/null 2>&1 || true
        ;;
      settings)
        if have blueman-manager; then
          run blueman-manager > /dev/null 2>&1 &
        else
          die "blueman-manager not installed (optional: pacman -S blueman)" 3
        fi
        return 0
        ;;
      device)
        mac=$arg
        if is_connected "$mac"; then
          run bluetoothctl disconnect "$mac" > /dev/null 2>&1 || true
          notify "disconnected"
        else
          connect_mac "$mac"
        fi
        return 0
        ;;
      *) return 0 ;;
    esac
  done
}

main() {
  while (($#)); do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      --json) JSON=1 ;;
      --rofi) ROFI=1 ;;
      --power)
        ACTION=power
        WANT=${2:-}
        [[ -n $WANT ]] || die "--power needs on, off or toggle" 2
        shift
        ;;
      --connect)
        ACTION=connect
        WANT=${2:-}
        [[ -n $WANT ]] || die "--connect needs an address" 2
        shift
        ;;
      status) ACTION=status ;;
      *) die "unexpected argument: $1" 2 ;;
    esac
    shift
  done

  require_bt
  case $ACTION in
    status)
      if ((JSON)); then status_json; else status_text; fi
      ;;
    power) set_power "$WANT" ;;
    connect) connect_mac "$WANT" ;;
  esac
  if ((ROFI)) && [[ $ACTION == status ]]; then bt_menu; fi
}

main "$@"
