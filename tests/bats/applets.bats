#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
  OSD="$ARCHWAY_ROOT/applets/osd/osd.sh"
  WALL="$ARCHWAY_ROOT/applets/wallpaper/wallpaper.sh"
  NET="$ARCHWAY_ROOT/applets/network/network.sh"
  CLIP="$ARCHWAY_ROOT/applets/clipboard/clipboard.sh"
}

teardown() {
  teardown_sandbox
}

@test "osd uses swayosd when it is installed" {
  mock_cmd swayosd-client 'printf "%s\n" "$*" >> "$HOME/osd.log"'
  run "$OSD" volume up
  assert_eq 0 "$status"
  assert_file_contains "$HOME/osd.log" "--output-volume raise"
}

@test "osd rejects an unknown volume action" {
  run "$OSD" volume louder
  assert_eq 2 "$status"
}

@test "osd dry-run prints the command instead of touching the mixer" {
  mock_cmd swayosd-client 'printf "%s\n" "$*" >> "$HOME/osd.log"'
  run "$OSD" --dry-run brightness down
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] swayosd-client --brightness lower"
  assert_missing "$HOME/osd.log"
}

@test "wallpaper lists images from the Archway data dir and ignores other files" {
  mkdir -p "$XDG_DATA_HOME/archway/wallpapers"
  printf 'x' > "$XDG_DATA_HOME/archway/wallpapers/a.png"
  printf 'x' > "$XDG_DATA_HOME/archway/wallpapers/notes.txt"
  run "$WALL" --json
  assert_eq 0 "$status"
  assert_contains "$output" "a.png"
  [[ $output != *notes.txt* ]] || fail "non-image file listed"
}

@test "wallpaper refuses a symlink and an unsupported extension" {
  mkdir -p "$XDG_DATA_HOME/archway/wallpapers"
  printf 'x' > "$SANDBOX/real.png"
  ln -s "$SANDBOX/real.png" "$XDG_DATA_HOME/archway/wallpapers/link.png"
  run "$WALL" --set "$XDG_DATA_HOME/archway/wallpapers/link.png"
  assert_eq 1 "$status"
  assert_contains "$output" "symlink"

  printf 'x' > "$SANDBOX/doc.pdf"
  run "$WALL" --set "$SANDBOX/doc.pdf"
  assert_eq 1 "$status"
  assert_contains "$output" "unsupported"
}

@test "wallpaper applies through hyprpaper and remembers the choice" {
  mkdir -p "$XDG_DATA_HOME/archway/wallpapers"
  printf 'x' > "$XDG_DATA_HOME/archway/wallpapers/a.png"
  mock_cmd pgrep 'exit 0'
  mock_cmd hyprctl 'printf "%s\n" "$*" >> "$HOME/hyprctl.log"'
  run "$WALL" --set "$XDG_DATA_HOME/archway/wallpapers/a.png"
  assert_eq 0 "$status"
  assert_file_contains "$HOME/hyprctl.log" "hyprpaper preload $XDG_DATA_HOME/archway/wallpapers/a.png"
  assert_file_contains "$HOME/hyprctl.log" "hyprpaper wallpaper ,$XDG_DATA_HOME/archway/wallpapers/a.png"
  assert_file_contains "$XDG_STATE_HOME/archway/wallpaper" "a.png"
}

@test "network dry-run does not change the radio" {
  mock_cmd nmcli 'printf "%s\n" "$*" >> "$HOME/nmcli.log"'
  run "$NET" --dry-run --wifi off
  assert_eq 0 "$status"
  assert_contains "$output" "nmcli radio wifi off"
  assert_missing "$HOME/nmcli.log"
}

@test "network menu lists networks with signal and lock state" {
  mock_cmd nmcli 'case "$*" in
    "radio wifi") printf "enabled\n" ;;
    *"device wifi list"*) printf "IN-USE:*\nSSID:HomeNet\nSIGNAL:82\nSECURITY:WPA2\nIN-USE:\nSSID:Cafe\nSIGNAL:44\nSECURITY:--\n" ;;
    *) printf "\n" ;;
  esac'
  mock_cmd rofi 'cat > "$HOME/rofi-input.log"; printf ""'
  run "$NET" --rofi
  assert_eq 0 "$status"
  assert_file_contains "$HOME/rofi-input.log" "HomeNet"
  assert_file_contains "$HOME/rofi-input.log" "Cafe"
  assert_file_contains "$HOME/rofi-input.log" "(connected)"
}

@test "clipboard reports an empty history and starts the watcher" {
  mock_cmd cliphist 'if [[ $1 == list ]]; then exit 0; fi'
  mock_cmd wl-paste 'sleep 5'
  mock_cmd wl-copy 'exit 0'
  run "$CLIP" --list --json
  assert_eq 0 "$status"
  assert_contains "$output" '"entries":0'
}
