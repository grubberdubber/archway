#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# migrate.sh — numbered, idempotent migrations executed exactly once.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_MIGRATE_LOADED:-} ]]; then return 0; fi
ARCHWAY_MIGRATE_LOADED=1

MIGRATIONS_DIR="$ARCHWAY_ROOT/scripts/migrations"

migrations_pending() {
  [[ -d $MIGRATIONS_DIR ]] || return 0
  local f name
  for f in "$MIGRATIONS_DIR"/[0-9][0-9][0-9][0-9]-*.sh; do
    [[ -e $f ]] || continue
    name=$(basename -- "$f")
    [[ -e $MIGRATION_STAMP_DIR/$name.done ]] && continue
    printf '%s\n' "$f"
  done | sort
}

migrations_run() {
  local pending
  pending=$(migrations_pending)
  if [[ -z $pending ]]; then
    debug "no pending migrations"
    return 0
  fi

  section "Migrations"
  local f name
  while IFS= read -r f; do
    name=$(basename -- "$f")
    info "running $name"
    # Migrations must be idempotent and safe to re-run after a crash.
    if ! bash "$f"; then
      err "migration failed: $name (stopping; previous migrations stay applied)"
      return 1
    fi
    if ((! DRY_RUN)); then
      ensure_dirs "$MIGRATION_STAMP_DIR"
      : > "$MIGRATION_STAMP_DIR/$name.done"
      chmod 600 "$MIGRATION_STAMP_DIR/$name.done"
    fi
  done <<< "$pending"
  ok "migrations applied"
}

migrations_list() {
  local f
  for f in "$MIGRATIONS_DIR"/[0-9][0-9][0-9][0-9]-*.sh; do
    [[ -e $f ]] || continue
    local name status='pending'
    name=$(basename -- "$f")
    [[ -e $MIGRATION_STAMP_DIR/$name.done ]] && status='applied'
    printf '%-40s %s\n' "$name" "$status"
  done
}
