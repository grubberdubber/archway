#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
}

teardown() {
  teardown_sandbox
}

@test "backup copies a file and records it in the manifest" {
  local target="$HOME/.config/kitty/kitty.conf"
  mkdir -p "$(dirname "$target")"
  printf 'font_size 11\n' > "$target"

  backup_file "$target"

  [[ -d $BACKUP_PATH/files/$HOME ]] || fail "payload missing"
  assert_file_contains "$BACKUP_PATH/manifest.tsv" "$target"
  assert_file_contains "$BACKUP_PATH/files/${target#/}" "font_size 11"
}

@test "restore brings back the original content" {
  local target="$HOME/.config/tmux/tmux.conf"
  mkdir -p "$(dirname "$target")"
  printf 'original\n' > "$target"

  backup_file "$target"
  local id
  id=$(basename "$BACKUP_PATH")
  printf 'clobbered\n' > "$target"

  restore_backup "$id"
  assert_eq "original" "$(cat "$target")"
}

@test "backing up a missing path is a no-op" {
  run backup_file "$HOME/does-not-exist"
  assert_eq 0 "$status"
  [[ ! -d $BACKUP_ROOT/$(today_stamp) ]] || [[ -z $(cat "$BACKUP_ROOT"/*/manifest.tsv 2> /dev/null) ]] ||
    fail "manifest should have no entries"
}

@test "backup sets are 0700" {
  local target="$HOME/.zshrc"
  printf 'x\n' > "$target"
  backup_file "$target"
  assert_eq "700" "$(stat -c '%a' "$BACKUP_PATH")"
}
