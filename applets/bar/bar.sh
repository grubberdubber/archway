#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bar.sh — waybar information modules that need real logic.
# shellcheck shell=bash
#
# Every section prints a waybar custom-module JSON object:
#   {"text": "...", "tooltip": "...", "class": "normal|warning|critical"}
# An empty `text` hides the module, which is how the bar stays short: a pill
# only exists while there is something to act on (AGENTS.md §9.2).
set -Eeuo pipefail

# `archway-bar` is a symlink into ~/.local/bin, so resolve the checkout from the
# real path to reach the sibling applets.
ARCHWAY_ROOT=${ARCHWAY_ROOT:-$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../.." && pwd)}

# Nerd Font glyphs as escapes: the terminal/tooling used to write this file
# drops private-use characters, so they are built at runtime.
icon() {
  # shellcheck disable=SC2059 # \uXXXX needs the escape to be part of the format.
  printf "\\u$1"
}

die() {
  printf 'archway-bar: %s\n' "$1" >&2
  exit "${2:-1}"
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

emit() {
  local text=$1 tooltip=${2:-} class=${3:-normal}
  printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' \
    "$(json_escape "$text")" "$(json_escape "$tooltip")" "$class"
}

have() { command -v "$1" > /dev/null 2>&1; }

# ------------------------------------------------------------- sections -----

# wf-recorder or OBS actually capturing.
section_recording() {
  local name=""
  if pgrep -x wf-recorder > /dev/null 2>&1; then name=wf-recorder; fi
  if pgrep -x obs > /dev/null 2>&1; then name=obs; fi
  if [[ -z $name ]]; then
    emit ""
    return 0
  fi
  emit "$(icon f03d) REC" "$name is recording the screen" critical
}

# Failed systemd units: the one thing on the bar that always deserves a look.
section_failed() {
  local count list
  have systemctl || {
    emit ""
    return 0
  }
  list=$(systemctl --failed --no-legend --no-pager 2> /dev/null | awk '{print $1}')
  count=$(printf '%s' "$list" | grep -c . || true)
  if [[ ${count:-0} -eq 0 ]]; then
    emit ""
    return 0
  fi
  emit "$(icon f071) ${count}" "failed:\n${list}" critical
}

# Pending package updates. `checkupdates` is offline-safe (sync db copy).
# The pill stays visible at zero: hiding it made the button look broken ("the
# updates button does nothing") exactly when the system was up to date.
# `checkupdates` keeps its sync-db copy in one shared temp directory and takes
# a lock there, so the bar refresh and a click on the pill used to collide:
# the second copy printed "==> ERROR: Cannot fetch updates" into the terminal.
# A private CHECKUPDATES_DB per invocation removes the shared lock entirely.
pending_updates() {
  local db
  db=$(mktemp -d)
  CHECKUPDATES_DB="$db" checkupdates 2> /dev/null || true
  rm -rf -- "$db" 2> /dev/null || true
}

section_updates() {
  local count err
  have checkupdates || {
    emit "$(icon f019) ?" "checkupdates is not installed (pacman-contrib)" muted
    return 0
  }
  err=$(mktemp)
  count=$(pending_updates 2> "$err" | grep -c . || true)
  # `checkupdates` takes a lock on its sync-db copy, so a second copy (the
  # click handler, a manual run) fails with "Cannot fetch updates". Say so
  # instead of reporting zero updates, which is a lie the user cannot see.
  if [[ ${count:-0} -eq 0 ]] && grep -qi 'error' "$err"; then
    rm -f -- "$err"
    emit "$(icon f019) ?" "could not check updates just now — click to retry" warning
    return 0
  fi
  rm -f -- "$err"
  if [[ ${count:-0} -eq 0 ]]; then
    emit "$(icon f00c)" "system is up to date — click to check again" muted
    return 0
  fi
  emit "$(icon f019) ${count}" "${count} package update(s) available — click to list them" warning
}

# `custom/updates` on-click: plain `pacman -Qu` instead of a second
# `checkupdates`. It needs no lock and no network, so clicking while the module
# refreshes cannot fail, and the list is the same one pacman would install.
updates_list() {
  local list count
  list=$(pending_updates)
  count=$(printf '%s\n' "$list" | grep -c . || true)
  if [[ ${count:-0} -eq 0 ]]; then
    printf 'No package updates pending.\n'
    return 0
  fi
  printf '%s\n\n' "$list"
  printf '%s pending update(s).\n' "$count"
  printf 'Update with: archway update\n'
}

# The media pill. The bar itself only shows icon + "artist — title"; the
# playback clock lives in the tooltip, where you look when you actually want it.
# A visible timer changed the pill width every second and dragged the whole
# centred row around with it. waybar's own mpris `{position}`/`{length}` stay at
# 00:00:00 for several players (mpv, Firefox video), so the numbers come from
# playerctl, which asks the player itself. It also keeps the pill in place while
# nothing plays, so the row never re-centres when a player stops.
section_media() {
  local status
  have playerctl || {
    emit "$(icon f001) —" "playerctl is not installed" muted
    return 0
  }
  status=$(playerctl status 2> /dev/null || true)
  if [[ -z $status ]]; then
    emit "$(icon f001) —" "no media player is running" muted
    return 0
  fi
  local player artist title album glyph full text tooltip clock cls=normal
  player=$(playerctl metadata --format '{{playerName}}' 2> /dev/null || true)
  artist=$(playerctl metadata --format '{{artist}}' 2> /dev/null || true)
  title=$(playerctl metadata --format '{{title}}' 2> /dev/null || true)
  album=$(playerctl metadata --format '{{album}}' 2> /dev/null || true)
  case ${player,,} in
    mpv*) glyph=$(icon f03d) ;;
    firefox*) glyph=$(icon f269) ;;
    spotify*) glyph=$(icon f1bc) ;;
    *) glyph=$(icon f001) ;;
  esac
  if [[ -n $artist && -n $title ]]; then
    full="$artist — $title"
  elif [[ -n $title ]]; then
    full=$title
  else
    full=${player:-media}
  fi
  # 14 characters, same budget the mpris module used: the pill is a reminder of
  # what is playing, not a scroller.
  text=$full
  if ((${#text} > 14)); then text="${text:0:13}…"; fi
  [[ $status == Playing ]] || cls=paused

  # <position> / <length>, resolved when the player reports both. Streams and
  # some Firefox pages answer position 0 with no length at all, and "0:00" on its
  # own is noise: then the line is left out and the tooltip keeps player + hint.
  clock=""
  local pos len
  pos=$(playerctl position 2> /dev/null || true)
  len=$(playerctl metadata --format '{{duration(mpris:length)}}' 2> /dev/null || true)
  if [[ -n $pos && -n $len && $len != 0:00 ]]; then
    pos=$(awk -v p="$pos" 'BEGIN{ printf "%d:%02d", p / 60, p % 60 }')
    clock="${pos} / ${len}"
  fi

  # Real newlines, not "\n": waybar draws the tooltip as Pango text and would
  # print a literal backslash-n. json_escape then turns them into JSON \n.
  tooltip=${player:-player}
  [[ -n $album ]] && tooltip+=$'\n'"$album"
  [[ -n $clock ]] && tooltip+=$'\n'"$clock"
  tooltip+=$'\nclick: play/pause · right-click: stop'
  emit "${glyph} ${text}" "$tooltip" "$cls"
}

# Gaming mode (applets/gaming): the rocket pill next to the power button.
section_gaming() {
  local applet="$ARCHWAY_ROOT/applets/gaming/gaming.sh"
  [[ -x $applet ]] || {
    emit ""
    return 0
  }
  if "$applet" status --json 2> /dev/null | grep -q '"enabled":true'; then
    emit "$(icon f135)" "gaming mode on — click to turn it off" active
  else
    emit "$(icon f135)" "gaming mode off — click for performance, DND, no idle" inactive
  fi
}

# Bitwarden vault locked: warns before an autofill silently fails.
section_vault() {
  local cfg=${XDG_CONFIG_HOME:-$HOME/.config}/rbw/config.json
  have rbw || {
    emit ""
    return 0
  }
  [[ -r $cfg ]] || {
    emit ""
    return 0
  }
  if rbw unlocked > /dev/null 2>&1; then
    emit ""
    return 0
  fi
  emit "$(icon f023)" "Bitwarden vault locked — Super+P to unlock" warning
}

# Tailscale or a WireGuard interface that is up.
section_vpn() {
  local iface ts
  if have tailscale; then
    ts=$(tailscale status --json 2> /dev/null | grep -c '"Online": true' || true)
    if [[ ${ts:-0} -gt 0 ]]; then
      emit "$(icon f023) ts" "tailscale: ${ts} peer(s) online" normal
      return 0
    fi
  fi
  if have wg; then
    iface=$(wg show interfaces 2> /dev/null | awk '{print $1}')
    if [[ -n $iface ]]; then
      emit "$(icon f023) ${iface}" "WireGuard: ${iface}" normal
      return 0
    fi
  fi
  emit ""
}

# Unread swaync notifications, with a do-not-disturb marker.
section_notifications() {
  local count dnd=0
  have swaync-client || {
    emit ""
    return 0
  }
  count=$(swaync-client -c 2> /dev/null || printf 0)
  [[ $(swaync-client -D 2> /dev/null) == true ]] && dnd=1
  # The bell stays on the bar with a zero count: hiding it made the centred row
  # jump every time the last notification was dismissed.
  if [[ ${count:-0} -eq 0 && $dnd -eq 0 ]]; then
    emit "$(icon f0f3) 0" "no unread notifications" muted
    return 0
  fi
  if [[ $dnd -eq 1 ]]; then
    emit "$(icon f1f6) ${count}" "do not disturb on" muted
  else
    emit "$(icon f0f3) ${count}" "${count} unread notification(s)" normal
  fi
}

# CPU, RAM and temperature, hidden until something is actually hot or full.
section_resources() {
  local cpu ram temp class=normal summary="" text=""
  cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5+$6+$7+$8; printf "%d", (u*100)/t}' /proc/stat 2> /dev/null || printf 0)
  ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d", ((t-a)*100)/t}' /proc/meminfo 2> /dev/null || printf 0)
  temp=0
  local f
  for f in /sys/class/thermal/thermal_zone*/temp; do
    [[ -r $f ]] || continue
    local v
    v=$(< "$f")
    ((v > 1000)) && v=$((v / 1000))
    ((v > temp)) && temp=$v
  done
  summary="cpu ${cpu}% · ram ${ram}%"
  ((temp > 0)) && summary+=" · ${temp}°C"
  # High thresholds on purpose: a laptop idling at 75 degrees is not news.
  if ((cpu >= 95 || ram >= 95 || temp >= 96)); then
    class=critical
  elif ((cpu >= 80 || ram >= 88 || (temp > 0 && temp > 90))); then
    class=warning
  fi
  text="$(icon f2db) ${cpu}% $(icon f0c9) ${ram}%"
  ((temp > 0)) && text+=" ${temp}°"
  emit "$text" "$summary" "$class"
}

# Root filesystem: only when free space is getting tight.
section_disk() {
  local pct free
  pct=$(df --output=pcent / 2> /dev/null | tail -1 | tr -dc '0-9')
  free=$(df -h --output=avail / 2> /dev/null | tail -1 | tr -d ' ')
  [[ -n $pct ]] || {
    emit ""
    return 0
  }
  local class=normal
  ((pct >= 90)) && class=warning
  ((pct >= 95)) && class=critical
  emit "$(icon f0a0) ${free}" "root filesystem ${pct}% used" "$class"
}

# Night light (gammastep) state; click toggles it.
section_nightlight() {
  have gammastep || {
    emit "$(icon f185)" "night light unavailable — install gammastep" muted
    return 0
  }
  if pgrep -x gammastep > /dev/null 2>&1; then
    emit "$(icon f186)" "night light on — click to turn off" normal
  else
    emit "$(icon f185)" "night light off — click to turn on" muted
  fi
}

nightlight_toggle() {
  if pgrep -x gammastep > /dev/null 2>&1; then
    pkill -x gammastep || true
    notify-send "Night light" "off" 2> /dev/null || true
    return 0
  fi
  have gammastep || die "gammastep is not installed" 3
  setsid gammastep -O 3500 > /dev/null 2>&1 &
  notify-send "Night light" "on (3500K)" 2> /dev/null || true
}

# Power profile from power-profiles-daemon.
section_power_profile() {
  local p
  have powerprofilesctl || {
    emit ""
    return 0
  }
  p=$(powerprofilesctl get 2> /dev/null) || {
    emit ""
    return 0
  }
  case $p in
    performance) emit "$(icon f135)" "performance profile" normal ;;
    power-saver) emit "$(icon f06c)" "power saver profile" normal ;;
    *) emit "$(icon f0e7)" "balanced profile" muted ;;
  esac
}

power_profile_next() {
  have powerprofilesctl || die "powerprofilesctl is not installed" 3
  local cur next
  cur=$(powerprofilesctl get)
  case $cur in
    performance) next=balanced ;;
    balanced) next=power-saver ;;
    *) next=performance ;;
  esac
  powerprofilesctl set "$next"
  notify-send "Power profile" "$next" 2> /dev/null || true
}

# Active keyboard layout ("us", "es"), from the main Hyprland keyboard.
section_language() {
  local layout=""
  have hyprctl || {
    emit ""
    return 0
  }
  layout=$(hyprctl -j devices 2> /dev/null |
    jq -r '[.keyboards[] | select(.main == true)][0].layout // empty' 2> /dev/null || true)
  [[ -n $layout ]] || {
    emit ""
    return 0
  }
  emit "$layout" "keyboard layout: ${layout}" normal
}

# Special (scratchpad) workspace has a hidden window.
section_scratchpad() {
  local n
  have hyprctl || {
    emit ""
    return 0
  }
  n=$(hyprctl -j clients 2> /dev/null |
    jq '[.[] | select(.workspace.name | startswith("special"))] | length' 2> /dev/null || printf 0)
  if [[ ${n:-0} -eq 0 ]]; then
    emit ""
    return 0
  fi
  emit "$(icon f2d0) ${n}" "${n} window(s) in the scratchpad — Super+grave" normal
}

usage() {
  cat << 'EOF'
usage: bar.sh <section>

sections:
  recording | failed | updates | vault | vpn | notifications
  resources | disk | nightlight | power-profile | scratchpad | language
  media | gaming

  updates --list           print pending updates (no lock, safe to click)
  nightlight --toggle      turn the night light on or off
  power-profile --next     cycle performance -> balanced -> power-saver
  gaming --toggle          enable or disable gaming mode

Each section prints one waybar custom-module JSON object; an empty text means
"hide this module", which is how the bar stays short.
EOF
}

main() {
  local section=${1:-}
  case $section in
    recording) section_recording ;;
    failed) section_failed ;;
    updates)
      if [[ ${2:-} == --list ]]; then updates_list; else section_updates; fi
      ;;
    vault) section_vault ;;
    vpn) section_vpn ;;
    notifications) section_notifications ;;
    media) section_media ;;
    gaming)
      if [[ ${2:-} == --toggle ]]; then
        exec "$ARCHWAY_ROOT/applets/gaming/gaming.sh" toggle
      fi
      section_gaming
      ;;
    resources) section_resources ;;
    disk) section_disk ;;
    scratchpad) section_scratchpad ;;
    language) section_language ;;
    nightlight)
      if [[ ${2:-} == --toggle ]]; then nightlight_toggle; else section_nightlight; fi
      ;;
    power-profile)
      if [[ ${2:-} == --next ]]; then power_profile_next; else section_power_profile; fi
      ;;
    -h | --help | help | "") usage ;;
    *) die "unknown section: ${section}" 2 ;;
  esac
}

main "$@"
