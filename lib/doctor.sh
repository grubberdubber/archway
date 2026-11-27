#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# doctor.sh — fast diagnostics (<5s) with human and JSON output.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_DOCTOR_LOADED:-} ]]; then return 0; fi
ARCHWAY_DOCTOR_LOADED=1

declare -ga DOC_NAME=() DOC_STATUS=() DOC_DETAIL=()

doctor_reset() { DOC_NAME=() DOC_STATUS=() DOC_DETAIL=(); }

doctor_add() {
  DOC_NAME+=("$1")
  DOC_STATUS+=("$2")
  DOC_DETAIL+=("$3")
}

# Installable package names must not appear in both an official and an AUR
# manifest: pacman would resolve one and silently shadow the other.
doctor_manifest_overlap() {
  local official aur overlap
  official=$(
    manifest_packages official-core
    manifest_packages official-desktop
    manifest_packages official-dev
    manifest_packages official-sec
    manifest_packages fonts
  )
  aur=$(
    manifest_packages aur-core
    manifest_packages aur-dev
    manifest_packages aur-sec
  )
  overlap=$(comm -12 <(printf '%s\n' "$official" | sort -u) <(printf '%s\n' "$aur" | sort -u))
  if [[ -n $overlap ]]; then
    doctor_add "manifests" fail "package(s) listed as both official and AUR: $(printf '%s ' "$overlap")"
  else
    doctor_add "manifests" ok "no official/AUR overlap"
  fi
}

doctor_run() {
  doctor_reset
  local detail

  # 1. Platform
  if [[ -f /etc/arch-release ]]; then
    doctor_add "platform" ok "Arch Linux detected"
  else
    doctor_add "platform" warn "not Arch Linux (unsupported, proceed carefully)"
  fi
  if ((EUID == 0)); then
    # Containers and CI legitimately run as root; only writes are refused.
    doctor_add "user" warn "running as root: read-only checks only, install/update are blocked"
  else
    doctor_add "user" ok "non-root user ($(id -un))"
  fi

  # 2. Runtime dependencies
  local missing=() c
  for c in bash git chezmoi; do have "$c" || missing+=("$c"); done
  if ((${#missing[@]})); then
    doctor_add "dependencies" warn "missing: ${missing[*]}"
  else
    doctor_add "dependencies" ok "bash, git, chezmoi present"
  fi
  if version_ge "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" "5.2"; then
    doctor_add "bash" ok "version ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
  else
    doctor_add "bash" fail "bash >= 5.2 required"
  fi

  # 3. State layout
  if [[ -d $STATE_DIR && -w $STATE_DIR ]]; then
    doctor_add "state" ok "writable: $STATE_DIR"
  elif [[ ! -e $STATE_DIR ]]; then
    doctor_add "state" ok "not created yet (install creates it)"
  else
    doctor_add "state" fail "not writable: $STATE_DIR"
  fi

  # 4. Theme
  if theme_exists android-mount; then
    if theme_validate android-mount > /dev/null 2>&1; then
      doctor_add "theme" ok "android-mount validates (AA contrast)"
    else
      doctor_add "theme" fail "android-mount failed validation (archway theme validate android-mount)"
    fi
  else
    doctor_add "theme" fail "themes/android-mount/palette.toml is missing"
  fi
  detail=$(current_theme)
  doctor_add "theme.current" ok "$detail"

  # Tools that read one generated file by fixed path. If the file drifts from
  # what the theme renders, the app silently keeps the previous palette.
  local yazi_live="$XDG_CONFIG_HOME/yazi/theme.toml" yazi_src="$THEME_D_DIR/yazi-theme.toml"
  if [[ ! -d $XDG_CONFIG_HOME/yazi ]]; then
    doctor_add "theme.yazi" ok "yazi not configured"
  elif [[ ! -e $yazi_live ]]; then
    doctor_add "theme.yazi" warn "theme.toml missing; run 'archway theme set $(current_theme)'"
  elif [[ -f $yazi_src ]] && ! keys_same_content "$yazi_src" "$yazi_live"; then
    doctor_add "theme.yazi" warn "theme.toml is stale; run 'archway theme set $(current_theme)'"
  else
    doctor_add "theme.yazi" ok "up to date"
  fi

  # 5. Keybinds + generated artifacts
  if keys_validate > /dev/null 2>&1; then
    doctor_add "keybinds" ok "valid"
  else
    doctor_add "keybinds" fail "invalid (archway keys validate)"
  fi
  if keys_check > /dev/null 2>&1; then
    doctor_add "keybinds.generated" ok "Hyprland binds and docs are in sync"
  else
    doctor_add "keybinds.generated" warn "generated files are stale (archway keys generate)"
  fi

  # 5a. Did the running session actually load the generated binds? Editing
  # keybinds.toml changes nothing until Hyprland reloads, and a chord that is
  # not loaded leaks to the focused window instead of failing loudly.
  keys_parse
  local bind_count=${#K_ID[@]} missing_binds='' loaded_rc=0
  missing_binds=$(keys_loaded_missing) || loaded_rc=$?
  case $loaded_rc in
    0) doctor_add "keybinds.loaded" ok "running session has all $bind_count binds" ;;
    2) doctor_add "keybinds.loaded" warn "no running Hyprland session to query" ;;
    *)
      if keys_live_stale; then
        doctor_add "keybinds.loaded" warn \
          "$(grep -c . <<< "$missing_binds") of $bind_count not in the session; the live file is stale: archway keys generate"
      else
        doctor_add "keybinds.loaded" warn \
          "$(grep -c . <<< "$missing_binds") of $bind_count not loaded; press Super+Alt+R or log out"
      fi
      ;;
  esac

  # 5b. Compositor and session components (ADR-013, ADR-014)
  if [[ -f $COMPAT_FILE ]]; then
    local hypr_status hypr_detail
    IFS=$'\t' read -r hypr_status hypr_detail < <(compat_check hyprland)
    doctor_add "hyprland" "$hypr_status" "$hypr_detail"
  else
    doctor_add "hyprland" warn "desktops/hyprland/compat.toml is missing"
  fi
  # 0.57 replaced hyprlang with a Lua API, so a config that still parses as
  # key=value silently produces a bare session. Ask the binary itself.
  local hypr_config="$XDG_CONFIG_HOME/hypr/hyprland.lua"
  if have Hyprland && [[ -f $hypr_config ]]; then
    local parsed
    parsed=$(timeout 15 Hyprland -c "$hypr_config" --verify-config 2>&1 | tail -n 5)
    if [[ $parsed == *"config ok"* ]]; then
      doctor_add "hyprland.config" ok "hyprland.lua parses"
    else
      doctor_add "hyprland.config" fail "hyprland.lua does not parse: $(printf '%s' "$parsed" | tr '\n' ' ')"
    fi
  fi
  local missing_session=() c
  for c in waybar swaync hyprlock hypridle; do have "$c" || missing_session+=("$c"); done
  if ((${#missing_session[@]})); then
    doctor_add "session" warn "missing: ${missing_session[*]}"
  else
    doctor_add "session" ok "waybar, swaync, hyprlock, hypridle present"
  fi
  if have uwsm; then
    doctor_add "uwsm" ok "session can be started through uwsm"
  else
    doctor_add "uwsm" warn "uwsm missing; start Hyprland through uwsm for systemd integration"
  fi

  # 5c. Shell loader: without ZDOTDIR the installed zsh tree is invisible and
  # the old ~/.zshrc keeps winning, which silently drops every Archway alias.
  if [[ ${SHELL:-} == */zsh ]]; then
    if grep -q 'archway-zsh' "$HOME/.zshenv" 2> /dev/null; then
      doctor_add "shell.zsh" ok "ZDOTDIR loader present in ~/.zshenv"
    else
      doctor_add "shell.zsh" warn "ZDOTDIR loader missing; run 'archway install --link-shell' so ~/.config/zsh is actually read"
    fi
  fi

  # 5d. Is the tracked configuration actually applied? `chezmoi status` is
  # read-only, so this is safe even on a production host.
  local dot_src="$ARCHWAY_ROOT/dotfiles" dot_drift=''
  if have chezmoi && [[ -d $dot_src ]]; then
    dot_drift=$(chezmoi --source "$dot_src" status 2> /dev/null | grep -c . || true)
    if [[ ${dot_drift:-0} -eq 0 ]]; then
      doctor_add "dotfiles" ok "every tracked file is applied"
    else
      doctor_add "dotfiles" warn "${dot_drift} tracked file(s) differ; run 'archway install' to reconcile"
    fi
  else
    doctor_add "dotfiles" warn "chezmoi is missing; cannot verify tracked dotfiles"
  fi

  # keyd lives in /etc, so toggling it needs root once. The narrow polkit rule
  # is what makes Super+Alt+N quiet; without it every toggle raises an
  # authentication dialog, and fails outright when no agent is running.
  if have keyd; then
    # The rule file itself is unreadable for a normal user: /etc/polkit-1/rules.d
    # is 0750 root:polkitd, so `[[ -r ]]` warned on a machine where the toggle
    # demonstrably worked. Test the capability instead, with the same action the
    # shortcut uses and with prompting disabled, so a missing grant fails fast
    # instead of opening a dialog in the middle of a health check. `reload` is
    # the cheapest verb the rule allows and changes no state.
    if systemctl is-active --quiet keyd 2> /dev/null; then
      # `start` on an already-active unit is a no-op that polkit still
      # authorises, so a 0 here is the same verdict the shortcut gets.
      if systemctl --no-ask-password --quiet start keyd 2> /dev/null; then
        doctor_add "keyd.grant" ok "polkit rule works; the toggle needs no password"
      else
        doctor_add "keyd.grant" warn "run 'archway applet keyd grant' once to toggle without a password"
      fi
    else
      # Nothing to probe without changing state (starting keyd would remap the
      # keyboard mid-check); say which state it is instead of guessing.
      doctor_add "keyd.grant" warn "keyd is stopped; start it with Super+Alt+N and re-run doctor"
    fi
  else
    doctor_add "keyd" ok "not installed (optional)"
  fi

  # 6. Package manifests
  doctor_manifest_overlap

  # 7. Neovim pin (never fatal for the desktop)
  if nvim_lock_verified; then
    # A commit pin has no tag; printing " @ sha" reads like a missing value.
    if [[ -n $(lock_get tag) ]]; then
      doctor_add "nvim.pin" ok "$(lock_get tag) @ $(lock_get commit)"
    else
      doctor_add "nvim.pin" ok "commit $(lock_get commit)"
    fi
  else
    doctor_add "nvim.pin" warn "unpinned placeholder (archway nvim pin <tag>)"
  fi
  # A user's own Neovim repo is not a defect. Only a checkout Archway manages
  # (recorded in nvim.conf) is held to the clean/pinned standard.
  local managed_commit
  managed_commit=$(state_get "$NVIM_STATE_FILE" commit || true)
  if [[ -d $NVIM_DIR/.git ]]; then
    if [[ -z $managed_commit ]]; then
      doctor_add "nvim.checkout" warn "existing checkout, not managed by Archway (install backs it up first)"
    elif nvim_checkout_clean; then
      doctor_add "nvim.checkout" ok "clean at $managed_commit"
    else
      doctor_add "nvim.checkout" fail "local changes in a managed checkout: $NVIM_DIR"
    fi
  else
    doctor_add "nvim.checkout" warn "not installed yet"
  fi

  # 8. Theme/Neovim hook
  local hook
  hook=$(theme_nvim_hook_target)
  if [[ -f $hook ]]; then
    doctor_add "nvim.theme_hook" ok "present"
  else
    doctor_add "nvim.theme_hook" warn "missing; run 'archway theme set android-mount'"
  fi

  doctor_report
}

doctor_report() {
  local fails=0 warns=0 i
  for i in "${!DOC_STATUS[@]}"; do
    case ${DOC_STATUS[i]} in
      fail) fails=$((fails + 1)) ;;
      warn) warns=$((warns + 1)) ;;
    esac
  done

  if ((JSON_OUT)); then
    local sep=''
    printf '{"ok":%s,"failures":%d,"warnings":%d,"checks":[' \
      "$([[ $fails -eq 0 ]] && echo true || echo false)" "$fails" "$warns"
    for i in "${!DOC_NAME[@]}"; do
      printf '%s{"name":%s,"status":%s,"detail":%s}' "$sep" \
        "$(json_str "${DOC_NAME[i]}")" "$(json_str "${DOC_STATUS[i]}")" "$(json_str "${DOC_DETAIL[i]}")"
      sep=','
    done
    printf ']}\n'
  else
    for i in "${!DOC_NAME[@]}"; do
      case ${DOC_STATUS[i]} in
        ok) printf '  %s✓%s %-20s %s\n' "$C_GREEN" "$C_RESET" "${DOC_NAME[i]}" "${DOC_DETAIL[i]}" >&2 ;;
        warn) printf '  %s!%s %-20s %s\n' "$C_YELLOW" "$C_RESET" "${DOC_NAME[i]}" "${DOC_DETAIL[i]}" >&2 ;;
        fail) printf '  %s✗%s %-20s %s\n' "$C_RED" "$C_RESET" "${DOC_NAME[i]}" "${DOC_DETAIL[i]}" >&2 ;;
      esac
    done
    printf '\n' >&2
    if ((fails)); then
      err "$fails critical issue(s), $warns warning(s)"
    else
      ok "doctor: no critical issues ($warns warning(s))"
    fi
  fi

  if ((fails == 0)); then
    return 0
  fi
  return 1
}
