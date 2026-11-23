#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
  FF="$ARCHWAY_ROOT/applets/firefox/firefox.sh"
  PROFILE_DIR="$XDG_CONFIG_HOME/mozilla/firefox/ab12cd34.default-release"
  ROOT_DIR="$XDG_CONFIG_HOME/mozilla/firefox"
  mkdir -p "$PROFILE_DIR"
  printf '[Install4F96D1932A9F858E]\nDefault=ab12cd34.default-release\nLocked=1\n' \
    > "$ROOT_DIR/installs.ini"
}

teardown() {
  teardown_sandbox
}

@test "firefox dry-run renders nothing" {
  run "$FF" --dry-run
  assert_eq 0 "$status"
  assert_contains "$output" "$PROFILE_DIR"
  assert_contains "$output" "[dry-run]"
  [[ ! -e $PROFILE_DIR/chrome/userChrome.css ]] || fail "dry-run wrote userChrome.css"
  assert_missing "$PROFILE_DIR/user.js"
}

@test "firefox theme writes chrome CSS, content CSS and prefs" {
  run "$FF"
  assert_eq 0 "$status"
  assert_file_contains "$PROFILE_DIR/chrome/userChrome.css" "--aw-bg: #0B0F14"
  assert_file_contains "$PROFILE_DIR/chrome/userContent.css" "--in-content-page-background: #0B0F14"
  # The portal picker is what broke focus and Ctrl+click in upload dialogs.
  assert_file_contains "$PROFILE_DIR/user.js" '"widget.use-xdg-desktop-portal.file-picker", 0'
  assert_file_contains "$PROFILE_DIR/user.js" "toolkit.legacyUserProfileCustomizations.stylesheets"
  # Square chrome: the template must not leave a radius behind.
  run grep -c 'border-radius: var' "$PROFILE_DIR/chrome/userChrome.css"
  assert_eq 1 "$status" # grep exits 1 when it finds nothing
}

@test "firefox follows the theme recorded by archway" {
  mkdir -p "$XDG_CONFIG_HOME/archway"
  printf 'theme=ember\n' > "$XDG_CONFIG_HOME/archway/theme.toml"
  run "$FF"
  assert_eq 0 "$status"
  run "$FF" status --json
  assert_contains "$output" '"theme":"ember"'
}

@test "firefox rejects an unknown theme" {
  run "$FF" --theme does-not-exist
  assert_eq 3 "$status"
  assert_contains "$output" "unknown theme"
}

@test "firefox --profile overrides discovery" {
  other="$HOME/other-profile"
  mkdir -p "$other"
  run "$FF" --profile "$other"
  assert_eq 0 "$status"
  assert_file_contains "$other/user.js" "file-picker"
}

@test "firefox status reports an unthemed profile" {
  run "$FF" status --json
  assert_eq 0 "$status"
  assert_contains "$output" '"chrome":false'
}
