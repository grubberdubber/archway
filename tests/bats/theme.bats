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

@test "contrast ratio of black on white is 21:1" {
  assert_eq "21.00" "$(contrast_ratio '#000000' '#FFFFFF')"
}

@test "contrast ratio is symmetric" {
  assert_eq "$(contrast_ratio '#8AB4F8' '#0B0F14')" "$(contrast_ratio '#0B0F14' '#8AB4F8')"
}

@test "palette parser reads hex colours, not comments" {
  theme_load_palette android-mount
  assert_eq "#0B0F14" "${PALETTE[bg]}"
  assert_eq "#E6EDF3" "${PALETTE[text]}"
  assert_eq "12" "${PALETTE[radius_window]}"
}

@test "android-mount passes AA validation" {
  run theme_validate android-mount
  assert_eq 0 "$status"
}

@test "every template renders without leaving tokens" {
  local dest="$SANDBOX/render"
  mkdir -p "$dest"
  theme_load_palette android-mount
  theme_render android-mount "$dest"
  run grep -rn '@[a-z_]*@' "$dest"
  assert_eq 1 "$status" # grep exits 1 when nothing matches
}

@test "rendered kitty config contains the palette background" {
  local dest="$SANDBOX/render"
  mkdir -p "$dest"
  theme_load_palette android-mount
  theme_render android-mount "$dest"
  assert_file_contains "$dest/kitty.conf" "background            #0B0F14"
}

@test "Neovim artifact matches the palette (contract)" {
  run theme_nvim_contract android-mount
  assert_eq 0 "$status"
}

@test "an invalid palette fails validation" {
  local dir="$SANDBOX/themes/bad"
  mkdir -p "$dir"
  printf '[palette]\nbg = "not-a-colour"\ntext = "#FFFFFF"\n' > "$dir/palette.toml"
  THEMES_DIR="$SANDBOX/themes" run theme_validate bad
  assert_eq 1 "$status"
}
