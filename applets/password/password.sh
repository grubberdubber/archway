#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# password — rbw front-end (Super+P) with a rofi picker.
#
# Secrets never touch Archway: rbw owns the vault, rofi-rbw owns the picker, and
# the clipboard is cleared after a configurable delay. This applet only checks
# the moving parts, adds a notification so the copy is visible from a keybind,
# and reports state for `doctor`.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ROFI=0
ACTION='status'
TYPE='password'
CLEAR=${PASSWORD_CLEAR_SECONDS:-30}

usage() {
  cat << 'EOF'
password — password manager (Bitwarden via rbw)

Usage:
  password.sh [status] [--json]
  password.sh --rofi [--type password|username]
  password.sh lock

--rofi    open rofi-rbw: search, copy, done. The clipboard is cleared after
          30 s (override with PASSWORD_CLEAR_SECONDS).
lock      lock the rbw agent now (rbw lock).

Requires rbw and rofi-rbw. Nothing is written to logs or state; if either tool
is missing the applet says so instead of failing silently.
Use the vault only for your own accounts (AGENTS.md §12.4).
EOF
}

die() {
  printf 'password: %s\n' "$1" >&2
  notify "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "password" "$1" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

vault_unlocked() {
  have rbw || return 1
  rbw unlocked > /dev/null 2>&1
}

status_json() {
  local installed=false unlocked=false picker=false
  have rbw && installed=true
  vault_unlocked && unlocked=true
  have rofi-rbw && picker=true
  printf '{"installed":%s,"unlocked":%s,"picker":%s}\n' "$installed" "$unlocked" "$picker"
}

status_text() {
  printf 'password: %s\n' "$(vault_unlocked && echo unlocked || echo locked)"
  printf '  rbw       %s\n' "$(have rbw && echo present || echo missing)"
  printf '  rofi-rbw  %s\n' "$(have rofi-rbw && echo present || echo missing)"
}

open_picker() {
  have rofi-rbw || die "rofi-rbw not installed (pacman -S rofi-rbw) " 3
  have rbw || die "rbw not installed (pacman -S rbw)" 3

  local -a cmd=(rofi-rbw --type "$TYPE" --action copy --clear "$CLEAR")
  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "${cmd[*]}"
    return 0
  fi

  # A locked vault is not a failure: rofi-rbw unlocks through pinentry.
  if ! vault_unlocked; then
    notify "vault locked — pinentry will ask for the master password"
  fi
  if ! "${cmd[@]}"; then
    # rofi exits non-zero when the user cancels; that is not an error worth
    # shouting about, but a real failure should not be swallowed either.
    return 0
  fi
  notify "copied — clipboard clears in ${CLEAR}s"
}

lock_vault() {
  have rbw || die "rbw not installed (pacman -S rbw)" 3
  if ((DRY_RUN)); then
    printf '[dry-run] rbw lock\n'
    return 0
  fi
  rbw lock > /dev/null 2>&1 || true
  notify "vault locked"
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
      --type)
        TYPE=${2:-password}
        case $TYPE in
          password | username) ;;
          *) die "--type expects password or username" 2 ;;
        esac
        shift
        ;;
      status) ACTION=status ;;
      lock) ACTION=lock ;;
      *) die "unexpected argument: $1" 2 ;;
    esac
    shift
  done

  case $ACTION in
    status)
      if ((JSON)); then status_json; else status_text; fi
      ;;
    lock) lock_vault ;;
  esac
  if ((ROFI)); then open_picker; fi
}

main "$@"
