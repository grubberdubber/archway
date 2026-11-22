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

@test "binds emit Hyprland Lua dispatchers, not shell wrappers" {
  local f="$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.lua"
  assert_file_contains "$f" 'hl.bind("SUPER + Q", hl.dsp.window.close())'
  # The terminal opens on the side of the cursor, so it goes through the applet.
  assert_file_contains "$f" 'hl.bind("SUPER + Return", hl.dsp.exec_cmd("$HOME/.local/bin/archway applet terminal"))'
  # Every modifier needs its own separator or Hyprland rejects the chord.
  assert_file_contains "$f" 'hl.bind("SUPER + SHIFT + Return"'
  run grep -q 'SUPER SHIFT +' "$f"
  assert_eq 1 "$status"
}

@test "sending a window to a workspace does not follow it" {
  local f="$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.lua"
  # `follow = false` is movetoworkspacesilent; without it Super+Shift+4 dragged
  # the whole session to workspace 4 instead of just the window.
  assert_file_contains "$f" 'hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4, follow = false }))'
  run grep -c 'window.move({ workspace = [0-9] })' "$f"
  assert_eq 1 "$status"
}

@test "media keys repeat and go through the OSD applet" {
  local f="$ARCHWAY_ROOT/dotfiles/dot_config/hypr/conf.d/20-keybinds.lua"
  assert_file_contains "$f" 'hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("$HOME/.local/bin/archway applet osd volume up"), { repeating = true })'
  assert_file_contains "$f" 'hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("$HOME/.local/bin/archway applet osd brightness down"), { repeating = true })'
  # No inline notify-send/pipe chains: the applet owns the fallback logic.
  run grep -q 'notify-send' "$f"
  assert_eq 1 "$status"
}

@test "a lowercase keysym is normalised to the name Hyprland expects" {
  assert_eq "SUPER|Space" "$(keys_split_chord 'super + space')"
  assert_eq "|Print" "$(keys_split_chord 'print')"
}

@test "an unknown dispatcher fails generation instead of emitting dead binds" {
  run keys_hypr_action workspacelast ""
  assert_eq 3 "$status"
  assert_contains "$output" "no Hyprland Lua mapping"
}

@test "chord split maps modifiers and keysym names" {
  assert_eq "SUPER SHIFT|Q" "$(keys_split_chord 'super + shift + q')"
  assert_eq "|Print" "$(keys_split_chord 'Print')"
  assert_eq "CTRL ALT|Escape" "$(keys_split_chord 'ctrl + alt + Escape')"
}

@test "binds not loaded by the running session are named" {
  # A stale compositor is silent: the chord falls through to the focused app.
  export HYPRLAND_INSTANCE_SIGNATURE=fake-session
  mock_cmd hyprctl 'printf "%s\n" "[{\"modmask\":64,\"key\":\"K\"},{\"modmask\":65,\"key\":\"K\"},{\"modmask\":72,\"key\":\"K\"}]"'
  run keys_loaded_missing
  assert_eq 1 "$status"
  assert_contains "$output" "super + alt + n"
  assert_contains "$output" "super + slash"
}

@test "no compositor session skips the loaded-bind check" {
  unset HYPRLAND_INSTANCE_SIGNATURE
  run keys_loaded_missing
  assert_eq 2 "$status"
  assert_eq "" "$output"
}
