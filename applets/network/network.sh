#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# network — Wi-Fi menu built on nmcli, with a rofi front-end.
#
# The previous flow opened nm-connection-editor (a GTK settings dialog) from the
# bar, which is heavy on a 1366x768 laptop and looks nothing like the rest of the
# desktop. This menu lists networks with signal/lock icons, toggles the radio and
# asks for the password in rofi — no extra daemon, no sudo, no secrets in argv.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ROFI=0
ACTION='menu'

usage() {
  cat << 'EOF'
network — Wi-Fi status and menu

Usage:
  network.sh [status] [--json]
  network.sh --rofi           # interactive menu (Super+Shift+N, bar click)
  network.sh --wifi on|off
  network.sh --connect <ssid>

Requires NetworkManager (nmcli). Passwords are read from rofi and handed to
nmcli through stdin-like arguments; they are never written to logs or state.
EOF
}

die() {
  printf 'network: %s\n' "$1" >&2
  notify "network" "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "$@" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

require_nm() {
  have nmcli || die "nmcli not found (pacman -S networkmanager)" 3
}

run() {
  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

radio_state() {
  nmcli radio wifi 2> /dev/null || printf 'unknown\n'
}

wifi_on() { [[ $(radio_state) == enabled ]]; }

# "IN-USE<TAB>SSID<TAB>SIGNAL<TAB>SECURITY", one row per visible network.
wifi_rows() {
  nmcli -m multiline \
    -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2> /dev/null |
    awk -F': ' '
      # nmcli aligns its multiline output into a column, so every value arrives
      # with leading padding (sometimes trailing too). Untrimmed, that padding
      # ends up inside the rofi rows and pushes the names off to the right.
      function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
      /^IN-USE:/   { inuse = (trim(substr($0, 8)) == "*") ? "*" : ""; next }
      /^SSID:/     { ssid = trim(substr($0, 6)); next }
      /^SIGNAL:/   { sig = trim(substr($0, 8)) + 0; next }
      /^SECURITY:/ {
        sec = trim(substr($0, 10))
        # A leading empty field would be swallowed by `read -r` (tabs are IFS
        # whitespace), shifting every column. Print a placeholder instead.
        mark = (inuse == "*") ? "*" : "-"
        if (ssid != "") print mark "\t" ssid "\t" sig "\t" sec
        ssid = ""
      }
    ' |
    awk -F'\t' '!seen[$2]++' |
    sort -t$'\t' -k3,3nr
}

signal_icon() {
  local sig=$1
  # Four blocks, filled by quartile. Blocks are monospace in every terminal font,
  # unlike the Nerd Font signal glyphs, which vary in width and made the list
  # look ragged. The private-use characters stay out of the source.
  if ((sig >= 75)); then
    printf '\u25cf\u25cf\u25cf\u25cf'
  elif ((sig >= 50)); then
    printf '\u25cf\u25cf\u25cf\u25cb'
  elif ((sig >= 25)); then
    printf '\u25cf\u25cf\u25cb\u25cb'
  else
    printf '\u25cf\u25cb\u25cb\u25cb'
  fi
}

security_icon() {
  case $1 in
    '' | --) printf '' ;;
    *) printf '\uf023' ;;
  esac
}

status_text() {
  local rows current='offline' dev state
  if ! wifi_on; then
    printf 'wifi off\n'
    return 0
  fi
  rows=$(wifi_rows) || true
  current=$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "*" { print $2; exit }')
  [[ -n $current ]] || current='disconnected'
  # A connected profile can hide its SSID from a fresh scan; fall back to the
  # device connection name so the bar never claims to be offline while online.
  if [[ $current == disconnected ]]; then
    dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2> /dev/null |
      awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')
    [[ -n $dev ]] && current=$(nmcli -t -f GENERAL.CONNECTION device show "$dev" 2> /dev/null | cut -d: -f2-)
  fi
  state=$(nmcli -t -f STATE general 2> /dev/null || true)
  printf '%s (%s)\n' "${current:-disconnected}" "${state:-unknown}"
}

status_json() {
  local ssid signal connected=false
  ssid=$(status_text 2> /dev/null | sed 's/ (.*//') || ssid=''
  if wifi_on && [[ -n $ssid && $ssid != offline && $ssid != disconnected ]]; then
    connected=true
    # Prefer the IN-USE row, but fall back to the SSID: a connection restored
    # from a saved profile does not always appear in the current scan.
    signal=$(wifi_rows | awk -F'\t' -v want="$ssid" '$1 == "*" || $2 == want { print $3; exit }')
  fi
  printf '{"wifi":%s,"radio":%s,"ssid":%s,"signal":%s}\n' \
    "$connected" "$(json_str "$(radio_state)")" "$(json_str "$ssid")" "${signal:-0}"
}

json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

ROFI_THEME=${ROFI_THEME:-$HOME/.config/archway/theme.d/rofi.rasi}

# A single-line masked prompt: the list is removed from mainbox entirely, so the
# window is as tall as the entry instead of reserving eight empty rows (the
# "empty panel with a cramped input on top" from before). The network name is
# the prompt; `password` sets the mask character so typing is visible.
ask_password() {
  local ssid=$1
  have rofi || return 1
  ((${#ssid} > 20)) && ssid="${ssid:0:19}…"
  rofi -dmenu -password -p "$ssid" -theme "$ROFI_THEME" \
    -theme-str 'mainbox { children: [ inputbar ]; } window { width: 24em; } inputbar { padding: 10px 12px; } entry { placeholder: "wi-fi password"; password: "●"; }'
}

connect_ssid() {
  local ssid=$1 sec=${2:-} password=''
  [[ -n $ssid ]] || die "connect: empty SSID" 2

  if [[ -n $sec && $sec != -- ]]; then
    password=$(ask_password "$ssid") || return 1
    [[ -n $password ]] || return 1
  fi

  local -a cmd=(nmcli device wifi connect "$ssid")
  if [[ -n $password ]]; then
    cmd+=(password "$password")
  fi

  if ((DRY_RUN)); then
    if [[ -n $password ]]; then
      printf '[dry-run] nmcli device wifi connect %s password <redacted>\n' "$ssid"
    else
      printf '[dry-run] nmcli device wifi connect %s\n' "$ssid"
    fi
    return 0
  fi

  if "${cmd[@]}" > /dev/null 2>&1; then
    notify "network" "connected to $ssid"
    return 0
  fi
  die "could not connect to $ssid (wrong password or out of range?)"
}

wifi_toggle() {
  local want=$1
  case $want in
    on) run nmcli radio wifi on ;;
    off) run nmcli radio wifi off ;;
    toggle)
      if wifi_on; then
        run nmcli radio wifi off
      else
        run nmcli radio wifi on
      fi
      ;;
    *) die "wifi: expected on, off or toggle" 2 ;;
  esac
}

# rofi 2.x splits a dmenu line into columns on runs of whitespace, so padding
# with spaces does not align anything: it renders as ragged columns with the
# last one right-aligned. Rows below therefore use exactly one space between
# fields; the four signal blocks are a constant width, which is what keeps the
# names on one column.
net_menu() {
  have rofi || die "rofi is required for the menu" 3
  local choice idx ssid sec
  local -a labels=() actions=()
  while true; do
    labels=()
    actions=()
    local rows name inuse sig security line
    if ! wifi_on; then
      labels+=('Enable Wi-Fi' 'Network settings')
      actions+=('radio' 'settings')
    else
      labels+=('Disable Wi-Fi' 'Rescan networks' 'Network settings')
      actions+=('radio' 'rescan' 'settings')
      rows=$(wifi_rows)
      # One pass to size the name column, one to build the rows: rofi shows a
      # single string per line, so alignment has to be baked into the text
      # instead of requested through -display-columns (which right-aligned the
      # last column and spaced everything else across the window).
      if [[ -n $rows ]]; then
        while IFS=$'\t' read -r inuse name sig security; do
          line="$(signal_icon "$sig") $name ${sig}%"
          [[ $inuse == "*" ]] && line+=' (connected)'
          [[ -n $security && $security != -- ]] && line+=" $(security_icon "$security")"
          labels+=("$line")
          actions+=("wifi:$name")
        done <<< "$rows"
      else
        labels+=('No networks found')
        actions+=('info')
      fi
    fi

    # Debug hook: print exactly what rofi is fed, then stop.
    if [[ ${NETWORK_MENU_DUMP:-0} == 1 ]]; then
      printf '%s\n' "${labels[@]}" | cat -A
      return 0
    fi

    # -format i returns the row number, so the action never has to survive a
    # round trip through the visible text (which is what mangled SSIDs with
    # spaces and made the old tab columns unreadable).
    choice=$(printf '%s\n' "${labels[@]}" |
      rofi -dmenu -i -p network -format i -theme "$ROFI_THEME") || return 0
    [[ -n $choice ]] || return 0
    idx=$choice
    ((idx >= 0 && idx < ${#actions[@]})) || return 0

    case ${actions[idx]} in
      radio) wifi_toggle toggle ;;
      rescan) nmcli device wifi rescan > /dev/null 2>&1 || true ;;
      settings) run nm-connection-editor > /dev/null 2>&1 || die "nm-connection-editor not found" 3 ;;
      wifi:*)
        ssid=${actions[idx]#wifi:}
        sec=$(wifi_rows | awk -F'\t' -v want="$ssid" '$2 == want { print $4; exit }')
        connect_ssid "$ssid" "$sec"
        return 0
        ;;
      info) return 0 ;;
      *) return 0 ;;
    esac
  done
}

main() {
  local connect='' want=''
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      --json) JSON=1 ;;
      --rofi) ROFI=1 ;;
      --wifi)
        ACTION=wifi
        want=${2:-}
        [[ -n $want ]] || die "--wifi needs on, off or toggle" 2
        shift
        ;;
      --connect)
        ACTION=connect
        connect=${2:-}
        [[ -n $connect ]] || die "--connect needs an SSID" 2
        shift
        ;;
      status) ACTION=status ;;
      *) die "unexpected argument: $1" 2 ;;
    esac
    shift
  done

  require_nm
  case $ACTION in
    status)
      if ((JSON)); then status_json; else status_text; fi
      ;;
    wifi) wifi_toggle "$want" ;;
    connect) connect_ssid "$connect" ;;
    menu)
      if ((ROFI)); then
        net_menu
      else
        status_text
      fi
      ;;
  esac
}

main "$@"
