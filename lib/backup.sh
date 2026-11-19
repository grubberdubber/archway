#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# backup.sh — timestamped backups with a manifest, plus restore.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_BACKUP_LOADED:-} ]]; then return 0; fi
ARCHWAY_BACKUP_LOADED=1

BACKUP_ID=''
BACKUP_PATH=''

# Start a backup set. Safe to call twice; the second call is a no-op.
backup_init() {
  [[ -n $BACKUP_PATH ]] && return 0
  BACKUP_ID=${BACKUP_ID:-$(today_stamp)}
  if ((DRY_RUN)); then
    BACKUP_PATH="$BACKUP_ROOT/$BACKUP_ID"
    ui_note "[dry-run] would create backup: $BACKUP_PATH"
    return 0
  fi
  ensure_dirs "$BACKUP_ROOT"
  chmod 700 -- "$BACKUP_ROOT"
  # Two backups can land in the same second (e.g. the safety backup taken by
  # `restore`). Never reuse a directory: that would clobber the payload.
  local candidate=$BACKUP_ID n=1
  while [[ -e $BACKUP_ROOT/$candidate ]]; do
    candidate="${BACKUP_ID}-${n}"
    n=$((n + 1))
  done
  BACKUP_ID=$candidate
  BACKUP_PATH="$BACKUP_ROOT/$BACKUP_ID"
  mkdir -p -- "$BACKUP_PATH/files"
  chmod 700 -- "$BACKUP_PATH" "$BACKUP_PATH/files"
  : > "$BACKUP_PATH/manifest.tsv"
  chmod 600 "$BACKUP_PATH/manifest.tsv"
  printf 'id=%s\nhost=%s\ncreated=%s\n' "$BACKUP_ID" "$(host_name)" "$(now_iso)" \
    > "$BACKUP_PATH/meta.conf"
  chmod 600 "$BACKUP_PATH/meta.conf"
  debug "backup set: $BACKUP_PATH"
}

# backup_file <absolute path> — copies preserving mode/timestamps under files/.
backup_file() {
  local src=$1
  [[ -e $src || -L $src ]] || return 0
  if [[ $src != /* ]]; then
    src="$PWD/$src"
  fi
  backup_init
  if ((DRY_RUN)); then
    ui_note "[dry-run] would back up: $src"
    return 0
  fi
  # --parents keeps the absolute hierarchy so restore is unambiguous.
  cp -a --parents -- "$src" "$BACKUP_PATH/files/" 2> /dev/null || {
    warn "could not back up $src"
    return 1
  }
  local rel=${src#/} sum=''
  have sha256sum && sum=$(sha256sum -- "$src" 2> /dev/null | cut -d' ' -f1)
  printf '%s\t%s\t%s\t%s\n' "$src" "$rel" "${sum:--}" "$(now_iso)" \
    >> "$BACKUP_PATH/manifest.tsv"
}

backup_files() {
  local f rc=0
  for f in "$@"; do
    backup_file "$f" || rc=1
  done
  return "$rc"
}

backup_list() {
  [[ -d $BACKUP_ROOT ]] || return 0
  local -a dirs=()
  local d
  while IFS= read -r d; do dirs+=("$d"); done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r)
  for d in "${dirs[@]}"; do
    local count
    count=$(wc -l < "$d/manifest.tsv" 2> /dev/null || printf 0)
    printf '%s\t%s files\n' "$(basename -- "$d")" "$count"
  done
}

backup_latest() {
  [[ -d $BACKUP_ROOT ]] || return 1
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n1
}

# restore_backup <id|path> [--dry-run aware]
restore_backup() {
  local ref=$1 dir
  [[ -n $ref ]] || die "restore requires a backup id (see 'archway backup list')" "$EX_USAGE"
  if [[ -d $ref ]]; then
    dir=$ref
  else
    dir="$BACKUP_ROOT/$ref"
  fi
  [[ -d $dir ]] || die "backup not found: $ref" "$EX_FAIL"
  [[ -r $dir/manifest.tsv ]] || die "backup has no manifest: $dir" "$EX_FAIL"

  local src rel target restored=0
  while IFS=$'\t' read -r src rel _sum _ts; do
    [[ -n $src ]] || continue
    if ((DRY_RUN)); then
      ui_item "[dry-run] restore $src"
      restored=$((restored + 1))
      continue
    fi
    [[ -e $dir/files/$rel ]] || {
      warn "missing backup payload for $src"
      continue
    }
    target=$src
    local payload="$dir/files/$rel"
    if [[ -d $payload && ! -L $payload ]]; then
      # Copy the *contents* over the existing directory. `cp -a dir dir`
      # would nest a second copy inside it, which is a classic restore bug.
      mkdir -p -- "$target"
      cp -a -- "$payload/." "$target/"
    else
      mkdir -p -- "$(dirname -- "$target")"
      cp -a -- "$payload" "$target"
    fi
    restored=$((restored + 1))
  done < "$dir/manifest.tsv"
  ok "restored $restored file(s) from $(basename -- "$dir")"
}
