#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
  CP="$ARCHWAY_ROOT/applets/color-picker/color-picker.sh"
  # The tests never touch the real clipboard or the notification daemon.
  export XDG_RUNTIME_DIR="$SANDBOX/run"
  mkdir -p "$XDG_RUNTIME_DIR"
}

teardown() {
  teardown_sandbox
}

@test "color-picker copies the picked colour and announces it" {
  mock_cmd hyprpicker 'printf "#f5a97f\n"'
  mock_cmd wl-copy 'cat > "$HOME/clipboard"'
  mock_cmd notify-send 'printf "%s\n" "$@" > "$HOME/notify"'
  # ImageMagick is not installed in the CI container: the stub only has to
  # leave the swatch behind, the applet checks that the file is real.
  mock_cmd magick ': > "$XDG_RUNTIME_DIR/archway/color.png"'

  run "$CP"
  assert_eq 0 "$status"
  assert_eq "#F5A97F" "$output"
  assert_eq "#F5A97F" "$(cat "$HOME/clipboard")"
  # The body carries the hex and the RGB triple, the swatch is the image.
  assert_file_contains "$HOME/notify" "#F5A97F"
  assert_file_contains "$HOME/notify" "rgb(245, 169, 127)"
  assert_file_contains "$HOME/notify" "image-path:$XDG_RUNTIME_DIR/archway/color.png"
}

@test "color-picker falls back to grim + slurp when hyprpicker is absent" {
  # `have hyprpicker` must fail, so the stub PATH holds only the fallback tools.
  mock_cmd slurp 'printf "10,20\n"'
  mock_cmd grim 'printf "%s\n" "$*" > "$HOME/grim.args"; printf "png"'
  mock_cmd magick 'printf "123456\n"'

  run "$CP" --no-copy
  assert_eq 0 "$status"
  assert_eq "#123456" "$output"
  # grim has to be asked for exactly one pixel at the selected point.
  assert_file_contains "$HOME/grim.args" "-g 10,20 1x1"
}

@test "color-picker reports a cancelled pick as exit 4" {
  mock_cmd hyprpicker 'exit 0'
  mock_cmd wl-copy 'cat > "$HOME/clipboard"'

  run "$CP"
  assert_eq 4 "$status"
  assert_contains "$output" "no colour picked"
  assert_missing "$HOME/clipboard"
}

@test "color-picker rejects a backend that prints something else" {
  mock_cmd hyprpicker 'printf "not-a-colour\n"'
  mock_cmd wl-copy 'cat > "$HOME/clipboard"'

  run "$CP"
  assert_eq 1 "$status"
  assert_contains "$output" "could not read a colour from hyprpicker"
  assert_missing "$HOME/clipboard"
}

@test "color-picker --no-copy leaves the clipboard alone" {
  mock_cmd hyprpicker 'printf "#0b0f14\n"'
  mock_cmd wl-copy 'cat > "$HOME/clipboard"'
  mock_cmd notify-send 'printf "%s\n" "$@" > "$HOME/notify"'

  run "$CP" --no-copy
  assert_eq 0 "$status"
  assert_eq "#0B0F14" "$output"
  assert_missing "$HOME/clipboard"
  assert_missing "$HOME/notify"
}

@test "color-picker --json describes the colour and the backend" {
  mock_cmd hyprpicker 'printf "#81c995\n"'
  mock_cmd wl-copy 'cat > "$HOME/clipboard"'
  mock_cmd notify-send 'true'

  run "$CP" --json
  assert_eq 0 "$status"
  assert_contains "$output" '"hex":"#81C995"'
  assert_contains "$output" '"r":129'
  assert_contains "$output" '"backend":"hyprpicker"'
}

@test "color-picker --dry-run names the backend and touches nothing" {
  mock_cmd hyprpicker 'printf "#ffffff\n"'
  mock_cmd wl-copy 'cat > "$HOME/clipboard"'

  run "$CP" --dry-run
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] backend: hyprpicker"
  assert_missing "$HOME/clipboard"
}

@test "color-picker explains the missing picker instead of failing silently" {
  # A PATH holding only bash keeps hyprpicker, grim, slurp and xcolor out of
  # reach while the shebang can still find an interpreter.
  mkdir -p "$SANDBOX/minbin"
  ln -s "$(command -v bash)" "$SANDBOX/minbin/bash"

  run env PATH="$SANDBOX/minbin" "$CP"
  assert_eq 1 "$status"
  assert_contains "$output" "no colour picker available"
}

@test "color-picker rejects an unknown flag with the usage exit code" {
  run "$CP" --nope
  assert_eq 2 "$status"
  assert_contains "$output" "unknown option"
}
