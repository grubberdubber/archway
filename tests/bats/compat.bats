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

@test "compat.toml declares the supported Hyprland window" {
  assert_eq "0.50.0" "$(compat_get hyprland minimum)"
  assert_eq "0.57.2" "$(compat_get hyprland tested)"
  assert_eq "0.9.7" "$(compat_get hyprlock tested)"
}

@test "a version below the minimum is a failure" {
  mock_cmd hyprctl 'printf "Hyprland 0.40.0 built from 0000000\n"'
  run compat_check hyprland
  assert_eq 0 "$status"
  assert_contains "$output" "fail"
  assert_contains "$output" "older than the supported minimum"
}

@test "a version newer than tested is only a warning" {
  mock_cmd hyprctl 'printf "Hyprland 0.61.0 built from 0000000\n"'
  run compat_check hyprland
  assert_contains "$output" "warn"
  assert_contains "$output" "newer than the tested"
}

@test "the tested version reports ok" {
  mock_cmd hyprctl 'printf "Hyprland 0.57.2 built from abc1234\n"'
  run compat_check hyprland
  assert_contains "$output" "ok"
}

@test "a missing compositor is a warning, never fatal" {
  run compat_check hyprland
  assert_contains "$output" "warn"
  assert_contains "$output" "not queryable"
}
