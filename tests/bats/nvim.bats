#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
  # The real lock lives in the checkout; every test here pins into a copy.
  NVIM_LOCK="$SANDBOX/nvim-config.lock"
  # The suite runs as root in the CI container; refuse-to-run-as-root is a CLI
  # guard, not part of what these tests exercise.
  require_not_root() { :; }
  cat > "$NVIM_LOCK" << 'EOF'
schema = 1
url = "https://github.com/example/nvim-config"
tag = ""
commit = ""
sha256 = ""
tested_neovim = "0.12.5"
channel = "stable"
unpinned = true
EOF
}

teardown() {
  teardown_sandbox
}

@test "nvim pin --commit records the commit and clears the unpinned flag" {
  local sha=0123456789abcdef0123456789abcdef01234567
  # Upstream has no release tags yet, so the archive is addressed by commit.
  mock_cmd curl 'while [ $# -gt 0 ]; do [ "$1" = -o ] && { : > "$2"; }; shift; done'
  mock_cmd sha256sum 'printf "%064d  %s\n" 0 "$2"'

  run nvim_pin --commit "$sha"
  assert_eq 0 "$status"
  assert_file_contains "$NVIM_LOCK" "commit = \"$sha\""
  assert_file_contains "$NVIM_LOCK" "channel = \"edge\""
  assert_file_contains "$NVIM_LOCK" "unpinned = false"
  assert_file_contains "$NVIM_LOCK" "sha256 = \"0000000000000000000000000000000000000000000000000000000000000000\""
}

@test "nvim pin --commit rejects a short sha before touching the lock" {
  run nvim_pin --commit abc123
  assert_eq 2 "$status"
  assert_file_contains "$NVIM_LOCK" "unpinned = true"
}

@test "nvim pin without an argument prints usage" {
  run nvim_pin
  assert_eq 2 "$status"
}

@test "a pinned lock is verified while the placeholder is not" {
  run nvim_lock_verified
  assert_eq 1 "$status"

  mock_cmd curl 'while [ $# -gt 0 ]; do [ "$1" = -o ] && { : > "$2"; }; shift; done'
  mock_cmd sha256sum 'printf "%064d  %s\n" 0 "$2"'
  nvim_pin --commit 0123456789abcdef0123456789abcdef01234567 > /dev/null

  run nvim_lock_verified
  assert_eq 0 "$status"
}
