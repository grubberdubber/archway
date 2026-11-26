#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# gaming — one switch that turns the session into a low-interference state.
#
# What it actually does (and why each part is there):
#   1. power-profiles-daemon -> performance: the firmware stops downclocking.
#   2. swaync -> do not disturb: no toast stealing focus or compositing.
#   3. hypridle -> paused (SIGSTOP, not killed): no lock, no dim, no suspend
#      while a game is focused, and it comes back with the previous state.
#   4. gamemode, when installed, is left to do per-process tuning: launching a
#      game with `gamemoderun` puts it in the same group, and Archway does not
#      reimplement cpu affinity here.
#
# Everything is reversible and nothing needs root: no sysfs writer, no governor
# poke, no service enable. Turning it off restores the saved profile and the
# previous notification mode, and resumes hypridle.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ACTION=''

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway"
STATE_FILE="$STATE_DIR/gaming.state"

usage() {
  cat << 'EOF'
gaming — ultra low-interference session mode

Usage:
  gaming.sh on | off | toggle
  gaming.sh status [--json]
  gaming.sh --dry-run <action>

On:  performance power profile, notifications silenced, idle/lock paused.
Off: restores the profile and notification mode saved when it was enabled.
reconcile: undo a mode left on by a previous boot (the session runs this at
           start; `status` also does, so the bar heals within one poll).
No root, no systemd changes; state lives in ~/.local/state/archway/gaming.state.
EOF
}

die() {
  printf 'gaming: %s\n' "$1" >&2
  exit "${2:-1}"
}

have() { command -v "$1" > /dev/null 2>&1; }

notify() {
  have notify-send && notify-send -a Archway "Gaming mode" "$1" > /dev/null 2>&1 || true
}

state_get() {
  local key=$1
  [[ -r $STATE_FILE ]] || return 0
  sed -n "s/^${key}=//p" "$STATE_FILE" | head -n1
}

boot_id() {
  cat /proc/sys/kernel/random/boot_id 2> /dev/null || printf 'unknown'
}

state_write() {
  local enabled=$1 profile=$2 dnd=$3 idle=$4
  ((DRY_RUN)) && return 0
  mkdir -p -- "$STATE_DIR"
  {
    printf 'enabled=%s\n' "$enabled"
    printf 'saved_profile=%s\n' "$profile"
    printf 'saved_dnd=%s\n' "$dnd"
    printf 'paused_hypridle=%s\n' "$idle"
    # Gaming mode is a session state, not a preference: a reboot ends it. The
    # boot id is what makes that checkable without a daemon.
    printf 'boot_id=%s\n' "$(boot_id)"
  } > "$STATE_FILE.tmp"
  mv -f -- "$STATE_FILE.tmp" "$STATE_FILE"
  chmod 644 -- "$STATE_FILE"
}

is_on() {
  [[ $(state_get enabled) == 1 ]] || return 1
  [[ $(state_get boot_id) == $(boot_id) ]]
}

# A shutdown with gaming mode on used to leave DND, the performance profile and
# the saved values behind, so the next login looked like gaming mode had turned
# itself on. Anything stamped with a different boot is undone here.
reconcile() {
  [[ $(state_get enabled) == 1 ]] || return 0
  [[ $(state_get boot_id) == $(boot_id) ]] && return 0

  local profile dnd idle
  profile=$(state_get saved_profile)
  dnd=$(state_get saved_dnd)
  idle=$(state_get paused_hypridle)
  [[ $idle == 1 ]] && pause_idle resume
  set_dnd "${dnd:-false}"
  set_profile "${profile:-balanced}"
  state_write 0 '' '' 0
  ((DRY_RUN)) && return 0
  printf 'gaming mode was left on by a previous boot; restored %s\n' "${profile:-balanced}"
  notify "reset after reboot — ${profile:-balanced} profile restored"
}

hypridle_running() { pgrep -x hypridle > /dev/null 2>&1; }
hypridle_paused() {
  local st
  hypridle_running || return 1
  st=$(awk '/^State:/ {print $2}' "/proc/$(pgrep -x hypridle | head -n1)/status" 2> /dev/null || true)
  [[ $st == T* ]]
}

set_profile() {
  local target=$1
  [[ -n $target ]] || return 0
  have powerprofilesctl || return 0
  if ((DRY_RUN)); then
    printf '[dry-run] powerprofilesctl set %s\n' "$target"
    return 0
  fi
  powerprofilesctl set "$target" > /dev/null 2>&1 || true
}

set_dnd() {
  local want=$1
  have swaync-client || return 0
  if ((DRY_RUN)); then
    printf '[dry-run] swaync-client -d%s\n' "${want:0:1}"
    return 0
  fi
  case $want in
    true) timeout 5 swaync-client -dn > /dev/null 2>&1 || true ;;
    false) timeout 5 swaync-client -df > /dev/null 2>&1 || true ;;
  esac
}

pause_idle() {
  local action=$1
  hypridle_running || return 0
  if ((DRY_RUN)); then
    printf '[dry-run] pkill -%s -x hypridle\n' "$([[ $action == pause ]] && echo STOP || echo CONT)"
    return 0
  fi
  if [[ $action == pause ]]; then
    pkill -STOP -x hypridle > /dev/null 2>&1 || true
  else
    pkill -CONT -x hypridle > /dev/null 2>&1 || true
  fi
}

enable() {
  if is_on; then
    printf 'gaming mode is already on\n'
    return 0
  fi
  local profile='' dnd='' idle=0
  have powerprofilesctl && profile=$(powerprofilesctl get 2> /dev/null || true)
  have swaync-client && dnd=$(swaync-client -D 2> /dev/null || true)
  hypridle_running && idle=1

  set_profile performance
  set_dnd true
  pause_idle pause
  state_write 1 "$profile" "${dnd:-false}" "$idle"

  ((DRY_RUN)) && return 0
  printf 'gaming mode on: performance profile, DND, idle paused'
  have gamemoderun && printf ' (gamemoderun available for per-game tuning)'
  printf '\n'
  notify "on — performance, DND, idle paused"
}

disable() {
  local profile dnd idle
  profile=$(state_get saved_profile)
  dnd=$(state_get saved_dnd)
  idle=$(state_get paused_hypridle)
  [[ $idle == 1 ]] && pause_idle resume
  set_dnd "${dnd:-false}"
  set_profile "${profile:-balanced}"
  state_write 0 '' '' 0
  ((DRY_RUN)) && return 0
  printf 'gaming mode off: %s profile restored, DND %s\n' \
    "${profile:-balanced}" "$([[ ${dnd:-false} == true ]] && echo kept || echo off)"
  notify "off — ${profile:-balanced} profile restored"
}

status() {
  local on=0 profile='' dnd='' idle=0 gamemode=0
  is_on && on=1
  have powerprofilesctl && profile=$(powerprofilesctl get 2> /dev/null || true)
  have swaync-client && dnd=$(swaync-client -D 2> /dev/null || true)
  hypridle_paused && idle=1
  have gamemoderun && gamemode=1
  if ((JSON)); then
    local on_json=false
    ((on)) && on_json=true
    printf '{"enabled":%s,"power_profile":"%s","dnd":"%s","idle_paused":%s,"gamemode":%s}\n' \
      "$on_json" "${profile:-unknown}" "${dnd:-unknown}" \
      "$([[ $idle == 1 ]] && echo true || echo false)" \
      "$([[ $gamemode == 1 ]] && echo true || echo false)"
    return 0
  fi
  if ((on)); then
    printf 'on\t%s · dnd %s · idle %s\n' "${profile:-unknown}" "${dnd:-?}" \
      "$([[ $idle == 1 ]] && echo paused || echo running)"
  else
    printf 'off\t%s · dnd %s\n' "${profile:-unknown}" "${dnd:-?}"
  fi
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    status | reconcile) ACTION=$1 ;;
    on | off | toggle) ACTION=$1 ;;
    *)
      printf 'gaming: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

case ${ACTION:-} in
  '')
    usage >&2
    exit 2
    ;;
  reconcile) reconcile ;;
  status)
    reconcile
    status
    ;;
  on)
    reconcile
    enable
    ;;
  off) disable ;;
  toggle)
    reconcile
    if is_on; then disable; else enable; fi
    ;;
esac
