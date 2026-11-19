#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# paths.sh — XDG layout, state directories and the single-instance lock.
# shellcheck shell=bash
# shellcheck disable=SC2034
# Shared XDG/state paths used by every lib file; shellcheck cannot see
# cross-file usage when a single lib is checked on its own.

if [[ -n ${ARCHWAY_PATHS_LOADED:-} ]]; then return 0; fi
ARCHWAY_PATHS_LOADED=1

: "${ARCHWAY_ROOT:?ARCHWAY_ROOT must be set before sourcing paths.sh}"

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

readonly CONFIG_DIR="$XDG_CONFIG_HOME/archway"
readonly STATE_DIR="$XDG_STATE_HOME/archway"
readonly CACHE_DIR="$XDG_CACHE_HOME/archway"
readonly DATA_DIR="$XDG_DATA_HOME/archway"

readonly LOG_DIR="$STATE_DIR/logs"
readonly BACKUP_ROOT="$STATE_DIR/backups"
readonly MIGRATION_STAMP_DIR="$STATE_DIR/migrations"
readonly MANAGED_MANIFEST="$STATE_DIR/managed.tsv"
readonly LOCK_FILE="$STATE_DIR/archway.lock"
readonly STATE_FILE="$STATE_DIR/state.conf"

readonly THEME_STATE_FILE="$CONFIG_DIR/theme.toml"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"
readonly THEME_D_DIR="$CONFIG_DIR/theme.d"
readonly NVIM_STATE_FILE="$STATE_DIR/nvim.conf"
readonly PROFILE_STATE_FILE="$STATE_DIR/profile.conf"

readonly REPO_SRC_DIR="$DATA_DIR/src"

ensure_dirs() {
  (($# == 0)) && set -- "$STATE_DIR" "$CONFIG_DIR" "$CACHE_DIR" "$DATA_DIR"
  local d
  for d in "$@"; do
    if [[ ! -d $d ]]; then
      mkdir -p -- "$d"
      chmod 700 -- "$d"
    fi
  done
}

log_init() {
  [[ -n $LOG_FILE ]] && return 0
  ensure_dirs "$LOG_DIR"
  LOG_FILE="$LOG_DIR/$(today_stamp)-$$.log"
  : > "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  readonly LOG_FILE
}

# Rotate logs cheaply: keep the 20 newest files.
log_rotate() {
  [[ -d $LOG_DIR ]] || return 0
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(ls -1t "$LOG_DIR"/*.log 2> /dev/null || true)
  ((${#files[@]} <= 20)) && return 0
  local old
  for old in "${files[@]:20}"; do rm -f -- "$old"; done
}

with_lock() {
  ensure_dirs "$STATE_DIR"
  exec 9> "$LOCK_FILE" || die "cannot open lock file: $LOCK_FILE"
  if ! flock -n 9; then
    die "another archway process is running (lock: $LOCK_FILE)" "$EX_FAIL"
  fi
  "$@"
}

# Hosts where install must not write unless explicitly allowed.
production_hosts() {
  local hosts="arch"
  if [[ -r $CONFIG_FILE ]]; then
    local value
    value=$(sed -n 's/^production_hosts[[:space:]]*=[[:space:]]*//p' "$CONFIG_FILE" | head -n1)
    [[ -n $value ]] && hosts=$value
  fi
  printf '%s' "$hosts"
}

is_production_host() {
  local h host
  h=$(host_name)
  for host in $(production_hosts | tr ',' ' '); do
    [[ $host == "$h" ]] && return 0
  done
  return 1
}
