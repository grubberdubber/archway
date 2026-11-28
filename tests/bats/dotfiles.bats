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

@test "workflow helpers are valid zsh and stay local" {
  # The Arch CI container ships bash only; the check runs on a real Arch host.
  command -v zsh > /dev/null || skip "zsh is not installed in this environment"
  local helpers="$ARCHWAY_ROOT/dotfiles/dot_config/zsh/conf.d/40-workflow.zsh"
  run zsh -n "$helpers"
  assert_eq 0 "$status"
  run zsh -f -c 'source "$1"; print -n "a b&c" | urlenc' _ "$helpers"
  assert_eq 0 "$status"
  assert_eq "a%20b%26c" "$output"
  # No helper may open an inbound socket on every interface.
  run grep -n 'http\.server.*0\.0\.0\.0' "$helpers"
  assert_eq 1 "$status"
  run grep -nF -- '--bind 127.0.0.1' "$helpers"
  assert_eq 0 "$status"
}

@test "the keymap module defaults to vi and keeps the arrow keys" {
  command -v zsh > /dev/null || skip "zsh is not installed in this environment"
  local keymap_file="$ARCHWAY_ROOT/dotfiles/dot_config/zsh/conf.d/05-keymap.zsh"
  run zsh -n "$keymap_file"
  assert_eq 0 "$status"
  # Vi is the default, and both keymaps get the same arrow behaviour.
  run grep -qF "bindkey -v" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "'^[[A' up-line-or-beginning-search" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "_archway_bind_common viins" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "_archway_bind_common vicmd" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "bindkey -M vicmd 'u' undo" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "bindkey -M vicmd 'L' end-of-line" "$keymap_file"
  assert_eq 0 "$status"
  # Backspace must delete in command mode, where zsh binds it to move-only.
  run grep -qF "'^?' backward-delete-char" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "'^H' backward-delete-char" "$keymap_file"
  assert_eq 0 "$status"
  # Readline keys stay usable in insert mode, where zsh leaves them unbound.
  run grep -qF "'^A' beginning-of-line" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF "'^K' kill-line" "$keymap_file"
  assert_eq 0 "$status"
  run grep -qF '_archway_bind_readline viins' "$keymap_file"
  assert_eq 0 "$status"
  # The mode is shown by the prompt symbol, not by repainting the message area.
  run grep -qF "zle -M '" "$keymap_file"
  assert_eq 1 "$status"
  # Sourcing it in a non-interactive shell must not fail on ZLE widgets.
  run zsh -f -c 'source "$1"; print ok' _ "$keymap_file"
  assert_eq 0 "$status"
  assert_eq "ok" "$output"
}

@test "atuin opens in the reference compact layout" {
  local config="$ARCHWAY_ROOT/dotfiles/dot_config/atuin/config.toml"
  assert_file_contains "$config" 'style = "compact"'
  assert_file_contains "$config" 'show_tabs = true'
  assert_file_contains "$config" 'show_preview = true'
  assert_file_contains "$config" 'show_help = false'
  assert_file_contains "$config" 'max_preview_height = 4'
}

@test "Tab completion uses fzf-tab when it is installed" {
  local tools_file="$ARCHWAY_ROOT/dotfiles/dot_config/zsh/conf.d/30-tools.zsh"
  run grep -qF 'fzf-tab-git/fzf-tab.zsh' "$tools_file"
  assert_eq 0 "$status"
  run grep -qF "zstyle ':completion:*' menu no" "$tools_file"
  assert_eq 0 "$status"
  # Three panes with the reference's labels, and previews for paths.
  run grep -qF -- "--input-label ' Search '" "$tools_file"
  assert_eq 0 "$status"
  run grep -qF -- "--list-label ' Results '" "$tools_file"
  assert_eq 0 "$status"
  run grep -qF -- "--preview-label ' Preview '" "$tools_file"
  assert_eq 0 "$status"
  run grep -qF "fzf-tab:complete:cd:*' fzf-preview" "$tools_file"
  assert_eq 0 "$status"
  # atuin must load after fzf so Ctrl-R keeps opening the history picker.
  local fzf_line atuin_line
  fzf_line=$(grep -nF 'source <(fzf --zsh)' "$tools_file" | cut -d: -f1)
  atuin_line=$(grep -nF 'atuin init zsh' "$tools_file" | head -1 | cut -d: -f1)
  [[ -n $fzf_line ]]
  [[ -n $atuin_line ]]
  ((atuin_line > fzf_line))
}

@test "the history module filters credentials and uses XDG state" {
  command -v zsh > /dev/null || skip "zsh is not installed in this environment"
  local history_file="$ARCHWAY_ROOT/dotfiles/dot_config/zsh/conf.d/35-history.zsh"
  run zsh -n "$history_file"
  assert_eq 0 "$status"
  run env XDG_STATE_HOME="$SANDBOX/state" zsh -f -c '
    source "$1"
    if _archway_private_command "export GITHUB_TOKEN=abc"; then print leaked; else print filtered; fi
    if _archway_private_command "curl -H Authorization: Bearer abc https://x"; then print leaked; else print filtered; fi
    if _archway_private_command "git status"; then print kept; else print dropped; fi
    print -r -- "$HISTFILE"
  ' _ "$history_file"
  assert_eq 0 "$status"
  assert_contains "$output" "filtered"
  assert_contains "$output" "kept"
  assert_contains "$output" "$SANDBOX/state/zsh/history"
  if [[ $output == *"leaked"* ]]; then
    fail "a credential-bearing command reached history"
  fi
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
