#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared test harness. Every test runs with a throwaway HOME so nothing can
# touch the developer's real configuration.
# shellcheck shell=bash

ARCHWAY_TEST_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
export ARCHWAY_ROOT="$ARCHWAY_TEST_ROOT"
export PATH="$ARCHWAY_ROOT/bin:$PATH"

# A test that leaves a child holding the runner's stdout would hang the suite
# forever (a real daemon started from an applet does exactly that). Fail the
# test instead: no Archway test legitimately needs a minute.
export BATS_TEST_TIMEOUT=${BATS_TEST_TIMEOUT:-60}

setup_sandbox() {
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/archway-test.XXXXXX")
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_STATE_HOME="$HOME/.local/state"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_DATA_HOME="$HOME/.local/share"
  mkdir -p -- "$HOME"

  # shellcheck source=../../lib/core.sh
  source "$ARCHWAY_ROOT/lib/core.sh"
  # shellcheck source=../../lib/paths.sh
  source "$ARCHWAY_ROOT/lib/paths.sh"
  # shellcheck source=../../lib/ui.sh
  source "$ARCHWAY_ROOT/lib/ui.sh"
  # shellcheck source=../../lib/state.sh
  source "$ARCHWAY_ROOT/lib/state.sh"
  # shellcheck source=../../lib/backup.sh
  source "$ARCHWAY_ROOT/lib/backup.sh"
  # shellcheck source=../../lib/theme.sh
  source "$ARCHWAY_ROOT/lib/theme.sh"
  # shellcheck source=../../lib/keys.sh
  source "$ARCHWAY_ROOT/lib/keys.sh"
  # shellcheck source=../../lib/packages.sh
  source "$ARCHWAY_ROOT/lib/packages.sh"
  # shellcheck source=../../lib/compat.sh
  source "$ARCHWAY_ROOT/lib/compat.sh"
  # shellcheck source=../../lib/nvim.sh
  source "$ARCHWAY_ROOT/lib/nvim.sh"
  # shellcheck source=../../lib/doctor.sh
  source "$ARCHWAY_ROOT/lib/doctor.sh"

  QUIET=1
  NO_COLOR=1
  JSON_OUT=0
  DRY_RUN=0
  ASSUME_YES=1
}

teardown_sandbox() {
  [[ -n ${SANDBOX:-} ]] && rm -rf -- "$SANDBOX"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

assert_eq() {
  local expected=$1 actual=$2 msg=${3:-values differ}
  [[ $expected == "$actual" ]] || fail "$msg (expected '$expected', got '$actual')"
}

assert_contains() {
  local haystack=$1 needle=$2 msg=${3:-substring not found}
  [[ $haystack == *"$needle"* ]] || fail "$msg ('$needle' not in output)"
}

assert_file_contains() {
  local file=$1 needle=$2
  [[ -r $file ]] || fail "file not found: $file"
  grep -qF -- "$needle" "$file" || fail "'$needle' not found in $file"
}

assert_missing() {
  [[ ! -e $1 ]] || fail "path should not exist: $1"
}

assert_dir_empty() {
  local dir=$1
  [[ -z $(ls -A -- "$dir" 2> /dev/null) ]] || fail "directory is not empty: $dir"
}

# Install a fake command into an isolated bin dir and prepend it to PATH.
mock_cmd() {
  local name=$1 body=$2
  local dir="$SANDBOX/bin"
  mkdir -p -- "$dir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$dir/$name"
  chmod +x "$dir/$name"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}
