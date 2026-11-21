#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# keyd — one shortcut to turn the one-hand numpad layer on and off.
#
# Why this exists: keyd lives in /etc and needs root, so a keyboard remap is the
# one part of the desktop a user cannot toggle comfortably. This applet keeps it
# honest:
#   * `on`/`off` only touch the service, never the config, and are idempotent;
#   * `install` writes the packaged layer, but only over a file Archway owns —
#     a foreign /etc/keyd/default.conf is reported, not replaced, unless the
#     caller passes `--replace`, and then the old file is kept with a timestamp;
#   * `reload` applies an edit without restarting the service, so a syntax error
#     leaves the previous mapping in place.
#
# Root is obtained through `sudo -n` when the credentials are already cached and
# through `pkexec` otherwise, so the same command works from a keybind (polkit
# agent) and from a terminal. Never runs as root itself.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
REPLACE=0
ACTION=''

# Both overrides exist so tests and containers can run the applet without root
# and without a real keyd: KEYD_DIR points at a throwaway config directory and
# KEYD_BIN at a fake binary.
KEYD_DIR=${KEYD_DIR:-/etc/keyd}
KEYD_CONF="$KEYD_DIR/default.conf"
KEYD_BIN=${KEYD_BIN:-keyd}
SELF_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
PACKAGED_CONF="$SELF_DIR/default.conf"
MARKER='# Managed by Archway (applet: keyd).'

usage() {
  cat << 'EOF'
keyd — CapsLock as Escape (tap) and one-hand numpad (hold)

Usage:
  keyd.sh status [--json]
  keyd.sh on | off | toggle
  keyd.sh install [--replace]
  keyd.sh reload
  keyd.sh --dry-run <action>

on        install the layer if /etc/keyd/default.conf is missing, then
          enable and start the keyd service (root via sudo -n or pkexec).
off       disable and stop the service; typing goes back to the firmware
          mapping immediately. The config file is left untouched.
          Needs root: sudo when credentials are cached, otherwise a pkexec
          prompt, which requires a running polkit agent (hyprpolkitagent on
          Hyprland; Archway starts it with the session).
toggle    on when keyd is off, off when it is on (this is the keybind).
install   write the packaged layer. A config Archway does not own is refused
          unless --replace is given; the previous file is kept as
          default.conf.bak.<timestamp>.
reload    keyd reload: apply an edited config without a restart.

The layer: tap CapsLock = Escape, hold CapsLock + j k l = 4 5 6, u i o = 7 8 9,
m , . = 1 2 3, n = 0. Nothing is remapped while the service is off.
Docs: docs/keyd.md
EOF
}

die() {
  printf 'keyd: %s\n' "$1" >&2
  notify "$1" || true
  exit "${2:-1}"
}

have() { command -v "$1" > /dev/null 2>&1; }
have_keyd() { command -v -- "$KEYD_BIN" > /dev/null 2>&1; }

notify() {
  have notify-send && notify-send -a Archway "keyd" "$1" > /dev/null 2>&1 || true
}

file_hash() { sha256sum -- "$1" | cut -d' ' -f1; }

service_active() { systemctl is-active --quiet keyd 2> /dev/null; }
service_enabled() { systemctl is-enabled --quiet keyd 2> /dev/null; }

# missing | managed | modified | foreign
config_state() {
  [[ -e $KEYD_CONF ]] || {
    printf 'missing'
    return 0
  }
  [[ -r $PACKAGED_CONF ]] || {
    printf 'present'
    return 0
  }
  if [[ $(file_hash "$KEYD_CONF") == "$(file_hash "$PACKAGED_CONF")" ]]; then
    printf 'managed'
    return 0
  fi
  if head -n 1 -- "$KEYD_CONF" 2> /dev/null | grep -qF -- "$MARKER"; then
    printf 'modified'
    return 0
  fi
  printf 'foreign'
}

# pkexec needs a running polkit *agent*. Without one it falls back to the
# textual agent, which cannot open /dev/tty from a keybind and fails with
# "Error creating textual authentication agent" — the reason toggling from the
# shortcut looked broken while the same command worked in a terminal.
polkit_agent_running() {
  pgrep -x hyprpolkitagent > /dev/null 2>&1 && return 0
  pgrep -f 'polkit-gnome-authentication-agent|polkit-kde-authentication-agent|lxqt-policykit|lxpolkit|mate-polkit' \
    > /dev/null 2>&1
}

# sudo only when it cannot prompt (a keybind has no terminal to prompt on);
# otherwise pkexec, which the polkit agent renders as a graphical dialog.
root_exec() {
  if ((EUID == 0)); then
    "$@"
    return
  fi
  if sudo -n true > /dev/null 2>&1; then
    sudo -n "$@"
    return
  fi
  if have pkexec; then
    if ! polkit_agent_running; then
      die "no polkit agent is running, so the password prompt cannot open; start hyprpolkitagent (Archway autostarts it on Hyprland) or run this from a terminal" 3
    fi
    pkexec "$@"
    return
  fi
  die "root is required for '$*' and neither sudo nor pkexec is usable" 3
}

run_root() {
  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  root_exec "$@"
}

install_config() {
  local state
  state=$(config_state)
  case $state in
    managed)
      printf 'keyd: packaged layer already in place (%s)\n' "$KEYD_CONF"
      return 0
      ;;
    missing)
      printf 'keyd: installing the packaged layer in %s\n' "$KEYD_CONF"
      ;;
    modified)
      ((REPLACE)) ||
        die "$KEYD_CONF is an edited Archway config; pass --replace to reset it" 1
      ;;
    foreign)
      ((REPLACE)) ||
        die "$KEYD_CONF is not managed by Archway; merge it by hand or pass --replace (a backup is kept)" 1
      ;;
    *)
      ;;
  esac

  if [[ -e $KEYD_CONF ]]; then
    local stamp backup
    stamp=$(date +%Y%m%dT%H%M%S)
    backup="$KEYD_CONF.bak.$stamp"
    run_root install -d -m 755 -- "$KEYD_DIR"
    run_root cp -a -- "$KEYD_CONF" "$backup"
    printf 'keyd: previous config kept at %s\n' "$backup"
  else
    run_root install -d -m 755 -- "$KEYD_DIR"
  fi
  run_root install -m 644 -- "$PACKAGED_CONF" "$KEYD_CONF"
  ((DRY_RUN)) || printf 'keyd: layer installed (%s)\n' "$KEYD_CONF"
}

require_keyd() {
  have_keyd || die "keyd is not installed (pacman -S keyd)" 3
}

start_service() {
  require_keyd
  # A missing file means nobody wrote a layer yet: install the packaged one. An
  # existing file is the user's (or an older Archway one) and is never touched
  # from `on`, so turning keyd on cannot silently change a mapping.
  if [[ $(config_state) == missing ]]; then
    install_config
  else
    printf 'keyd: using existing config (%s)\n' "$KEYD_CONF"
  fi
  if service_active && service_enabled; then
    printf 'keyd: already on\n'
    return 0
  fi
  run_root systemctl enable --now keyd || die "could not enable keyd (see: journalctl -u keyd)" 1
  ((DRY_RUN)) && return 0
  service_active || die "keyd was enabled but is not running (journalctl -u keyd)" 1
  printf 'keyd: on — CapsLock tap = Esc, hold = numpad\n'
  notify "on — CapsLock tap = Esc, hold = numpad"
}

stop_service() {
  if ! have_keyd; then
    printf 'keyd: not installed, nothing to turn off\n'
    return 0
  fi
  if ! service_active && ! service_enabled; then
    printf 'keyd: already off\n'
    return 0
  fi
  run_root systemctl disable --now keyd || die "could not disable keyd" 1
  ((DRY_RUN)) && return 0
  printf 'keyd: off — firmware keyboard mapping restored\n'
  notify "off — firmware keyboard mapping restored"
}

reload_service() {
  require_keyd
  service_active || die "keyd is not running; turn it on first" 1
  run_root "$KEYD_BIN" reload || die "keyd reload failed; the previous mapping is still active" 1
  ((DRY_RUN)) && return 0
  printf 'keyd: configuration reloaded\n'
  notify "configuration reloaded"
}

status() {
  local installed=false active=false enabled=false state
  have_keyd && installed=true
  service_active && active=true
  service_enabled && enabled=true
  state=$(config_state)

  if ((JSON)); then
    printf '{"installed":%s,"active":%s,"enabled":%s,"config":"%s","path":"%s"}\n' \
      "$installed" "$active" "$enabled" "$state" "$KEYD_CONF"
    return 0
  fi
  printf 'keyd: %s\n' "$([[ $active == true ]] && echo on || echo off)"
  printf '  installed  %s\n' "$installed"
  printf '  active     %s\n' "$active"
  printf '  enabled    %s\n' "$enabled"
  printf '  config     %s (%s)\n' "$state" "$KEYD_CONF"
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    --replace) REPLACE=1 ;;
    status | on | off | toggle | install | reload) ACTION=$1 ;;
    *)
      printf 'keyd: unknown option: %s\n' "$1" >&2
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
  status) status ;;
  install) install_config ;;
  on) start_service ;;
  off) stop_service ;;
  reload) reload_service ;;
  toggle)
    if service_active; then
      stop_service
    else
      start_service
    fi
    ;;
esac
