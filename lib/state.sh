#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# state.sh — small key=value state files and the managed-file manifest.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_STATE_LOADED:-} ]]; then return 0; fi
ARCHWAY_STATE_LOADED=1

state_get() {
  local file=$1 key=$2
  [[ -r $file ]] || return 1
  local line
  line=$(grep -m1 -E "^${key}=" "$file" 2> /dev/null) || return 1
  printf '%s' "${line#*=}"
}

# Atomic, permission-restricted write of a single key.
state_set() {
  local file=$1 key=$2 value=$3
  ensure_dirs "$(dirname -- "$file")"
  local tmp
  tmp=$(mktemp "${file}.XXXXXX")
  chmod 600 "$tmp"
  if [[ -r $file ]]; then
    grep -v -E "^${key}=" "$file" > "$tmp" || true
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv -f -- "$tmp" "$file"
}

state_delete() {
  local file=$1 key=$2 tmp
  [[ -r $file ]] || return 0
  tmp=$(mktemp "${file}.XXXXXX")
  grep -v -E "^${key}=" "$file" > "$tmp" || true
  mv -f -- "$tmp" "$file"
}

record_managed() {
  local path=$1 origin=${2:-dotfiles}
  ensure_dirs "$STATE_DIR"
  touch "$MANAGED_MANIFEST"
  chmod 600 "$MANAGED_MANIFEST"
  grep -qxF "$path" "$MANAGED_MANIFEST" 2> /dev/null && return 0
  printf '%s\t%s\t%s\n' "$path" "$origin" "$(now_iso)" >> "$MANAGED_MANIFEST"
}

is_managed() {
  local path=$1
  [[ -r $MANAGED_MANIFEST ]] || return 1
  cut -f1 "$MANAGED_MANIFEST" | grep -qxF -- "$path"
}

managed_paths() {
  [[ -r $MANAGED_MANIFEST ]] || return 0
  cut -f1 "$MANAGED_MANIFEST" | sort -u
}

# Remove a managed path, keeping user data and never following symlinks blindly.
forget_managed() {
  local path=$1
  [[ -r $MANAGED_MANIFEST ]] || return 0
  local tmp
  tmp=$(mktemp "${MANAGED_MANIFEST}.XXXXXX")
  awk -F'\t' -v p="$path" '$1 != p' "$MANAGED_MANIFEST" > "$tmp" || true
  mv -f -- "$tmp" "$MANAGED_MANIFEST"
}

archway_version() {
  local v
  v=$(< "$ARCHWAY_ROOT/VERSION") || v=unknown
  printf '%s' "$(trim "$v")"
}

archway_commit() {
  if [[ -d $ARCHWAY_ROOT/.git ]] && have git; then
    git -C "$ARCHWAY_ROOT" rev-parse --short HEAD 2> /dev/null || printf 'unknown'
  else
    printf 'unknown'
  fi
}

archway_channel() {
  state_get "$STATE_FILE" channel || printf 'stable'
}

current_profile() {
  state_get "$PROFILE_STATE_FILE" profile || printf 'none'
}

current_theme() {
  state_get "$THEME_STATE_FILE" theme || printf 'none'
}
