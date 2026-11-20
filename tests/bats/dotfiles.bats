#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
  # shellcheck source=../../lib/install.sh
  source "$ARCHWAY_ROOT/lib/install.sh"
}

teardown() {
  teardown_sandbox
}

@test "a target maps back to the chezmoi source path with dot_ prefixes" {
  assert_eq "$ARCHWAY_ROOT/dotfiles/dot_config/zsh/dot_zshrc" \
    "$(dotfiles_target_source "$HOME/.config/zsh/.zshrc")"
  assert_eq "$ARCHWAY_ROOT/dotfiles/dot_local/share/x/y" \
    "$(dotfiles_target_source "$HOME/.local/share/x/y")"
  run dotfiles_target_source "/etc/hosts"
  assert_eq 1 "$status"
}

@test "pruning stale artifacts never removes a live dotfile" {
  local src="$SANDBOX/src"
  mkdir -p "$src/dot_config/zsh" "$HOME/.config/zsh"
  printf 'zshrc\n' > "$src/dot_config/zsh/dot_zshrc"
  printf 'user config\n' > "$HOME/.config/zsh/.zshrc"

  DOTFILES_SRC="$src"
  ensure_dirs "$STATE_DIR"
  printf '%s\t%s\t%s\n' "$HOME/.config/zsh/.zshrc" chezmoi "2026-01-01T00:00:00" > "$MANAGED_MANIFEST"

  run dotfiles_prune_stale
  assert_eq 0 "$status"
  [[ -f $HOME/.config/zsh/.zshrc ]] || fail "live dotfile was pruned"
}

@test "pruning removes a managed artifact that left the source" {
  local src="$SANDBOX/src"
  mkdir -p "$src/dot_config/hypr" "$HOME/.config/hypr"
  printf 'lua\n' > "$src/dot_config/hypr/hyprland.lua"
  printf 'old\n' > "$HOME/.config/hypr/hyprland.conf"

  DOTFILES_SRC="$src"
  ensure_dirs "$STATE_DIR"
  printf '%s\t%s\t%s\n' "$HOME/.config/hypr/hyprland.conf" chezmoi "2026-01-01T00:00:00" > "$MANAGED_MANIFEST"

  run dotfiles_prune_stale
  assert_eq 0 "$status"
  assert_missing "$HOME/.config/hypr/hyprland.conf"
  run grep -c hyprland.conf "$MANAGED_MANIFEST"
  assert_eq 1 "$status"
}
