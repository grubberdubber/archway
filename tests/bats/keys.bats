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

@test "chords normalise regardless of modifier order" {
  assert_eq "alt+shift+super+t" "$(keys_normalize 'Shift + Super + Alt + T')"
  assert_eq "$(keys_normalize 'ctrl + q')" "$(keys_normalize 'Control + Q')"
}

@test "shipped keybinds are valid and unique" {
  run keys_validate
  assert_eq 0 "$status"
}

@test "duplicate chords are rejected" {
  local file="$SANDBOX/dupes.toml"
  cat > "$file" << 'EOF'
[[keybind]]
id = "one"
keys = "super + x"
command = "true"
category = "test"

[[keybind]]
id = "two"
keys = "Super+X"
command = "true"
category = "test"
EOF
  KEYBINDS_FILE="$file" run keys_validate
  assert_eq 1 "$status"
  assert_contains "$output" "duplicate chord"
}

@test "reserved kernel combinations are rejected" {
  local file="$SANDBOX/reserved.toml"
  cat > "$file" << 'EOF'
[[keybind]]
id = "vt"
keys = "ctrl + alt + F2"
command = "true"
category = "test"
EOF
  KEYBINDS_FILE="$file" run keys_validate
  assert_eq 1 "$status"
  assert_contains "$output" "reserved"
}

@test "generated Hyprland binds are in sync with the source" {
  run keys_check
  assert_eq 0 "$status"
}

@test "binds emit native Hyprland dispatchers, not shell wrappers" {
  assert_file_contains "$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.conf" \
    "bind = SUPER, Q, killactive"
  assert_file_contains "$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.conf" \
    "bind = SUPER, Return, exec, kitty"
}

@test "media keys repeat and use wayland clipboard" {
  assert_file_contains "$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.conf" \
    "binde = , XF86AudioRaiseVolume"
  assert_file_contains "$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.conf" "wl-copy"
}

@test "chord split maps modifiers and keysym names" {
  assert_eq "SUPER SHIFT|Q" "$(keys_split_chord 'super + shift + q')"
  assert_eq "|Print" "$(keys_split_chord 'Print')"
  assert_eq "CTRL ALT|Escape" "$(keys_split_chord 'ctrl + alt + Escape')"
}
