#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# install.sh — preflight, plan, backup, apply. Writes only after consent.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_INSTALL_LOADED:-} ]]; then return 0; fi
ARCHWAY_INSTALL_LOADED=1

DOTFILES_SRC="$ARCHWAY_ROOT/dotfiles"

# Configuration paths Archway may touch. Used for the backup set.
archway_config_paths() {
  local p
  for p in \
    "$XDG_CONFIG_HOME/hypr" \
    "$XDG_CONFIG_HOME/waybar" \
    "$XDG_CONFIG_HOME/swaync" \
    "$XDG_CONFIG_HOME/kitty" \
    "$XDG_CONFIG_HOME/rofi" \
    "$XDG_CONFIG_HOME/tmux" \
    "$XDG_CONFIG_HOME/zsh" \
    "$XDG_CONFIG_HOME/starship.toml"; do
    if [[ -e $p ]]; then
      printf '%s\n' "$p"
    fi
  done
  # Always succeed: a missing path is normal, not an error under `set -e`.
  return 0
}

preflight_summary() {
  local free_kb free_gb min_gb=${ARCHWAY_MIN_SPACE_GB:-10}
  free_kb=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
  free_gb=$((free_kb / 1024 / 1024))
  ui_kv "host" "$(host_name)"
  ui_kv "user" "$(id -un)"
  ui_kv "archway" "$(archway_version) ($(archway_commit))"
  ui_kv "free disk" "${free_gb} GB"
  if ((free_gb < min_gb)); then
    warn "less than ${min_gb} GB free on $HOME"
  fi
  if is_production_host; then
    ui_kv "host class" "production (writes blocked unless --apply-production)"
  fi
}

preflight_checks() {
  require_not_root
  require_cmd bash git
  if ! have chezmoi; then
    die "chezmoi is required (pacman -S chezmoi). Archway will not fall back to a custom dotfile manager." "$EX_PREFLIGHT"
  fi
  [[ -d $DOTFILES_SRC ]] || die "missing dotfiles source: $DOTFILES_SRC" "$EX_PREFLIGHT"
  [[ -d /etc ]] || die "unexpected environment" "$EX_PREFLIGHT"
  if [[ ! -f /etc/arch-release ]]; then
    warn "this does not look like Arch Linux; continuing because --dry-run/VM use may differ"
  fi
}

dotfiles_status() {
  # `status` is read-only: it lists what apply would change.
  chezmoi --source "$DOTFILES_SRC" status 2> /dev/null || true
}

# chezmoi never deletes targets that disappeared from the source, so renaming a
# managed file (hyprland.conf -> hyprland.lua) leaves the old artifact behind and
# Hyprland could still pick it up. Remove only files Archway recorded as managed
# whose source no longer exists; user files are never touched.
# Map a target path back to its chezmoi source path: every component that
# starts with a dot becomes `dot_<name>` (`.config/zsh/.zshrc` ->
# `dot_config/zsh/dot_zshrc`). Getting this wrong prunes live user files.
dotfiles_target_source() {
  local target=$1 rel part dir
  [[ $target == "$HOME"/* ]] || return 1
  rel=${target#"$HOME"/}
  [[ -n $rel ]] || return 1
  local -a parts=() mapped=()
  IFS=/ read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    if [[ $part == .* ]]; then
      part="dot_${part#.}"
    fi
    mapped+=("$part")
  done
  dir=$(
    IFS=/
    printf '%s' "${mapped[*]}"
  )
  printf '%s/%s' "$DOTFILES_SRC" "$dir"
}

dotfiles_prune_stale() {
  [[ -r $MANAGED_MANIFEST ]] || return 0
  local path origin stamp src
  local -a keep=() removed=()
  while IFS=$'\t' read -r path origin stamp; do
    [[ -n $path ]] || continue
    if [[ $origin != chezmoi ]] || ! src=$(dotfiles_target_source "$path"); then
      keep+=("$path"$'\t'"$origin"$'\t'"$stamp")
      continue
    fi
    if [[ -e $src || -e $src.tmpl ]]; then
      keep+=("$path"$'\t'"$origin"$'\t'"$stamp")
      continue
    fi
    if ((DRY_RUN)); then
      ui_note "[dry-run] would remove stale managed file: $path"
      keep+=("$path"$'\t'"$origin"$'\t'"$stamp")
      continue
    fi
    if [[ -f $path ]]; then
      rm -f -- "$path"
      removed+=("$path")
    elif [[ -d $path ]] && rmdir -- "$path" 2> /dev/null; then
      removed+=("$path")
    else
      keep+=("$path"$'\t'"$origin"$'\t'"$stamp")
    fi
  done < "$MANAGED_MANIFEST"
  ((${#removed[@]})) || return 0
  printf '%s\n' "${keep[@]}" > "$MANAGED_MANIFEST.tmp"
  mv -f -- "$MANAGED_MANIFEST.tmp" "$MANAGED_MANIFEST"
  ui_note "removed ${#removed[@]} stale managed file(s)"
  printf '  %s\n' "${removed[@]}" >&2
}

dotfiles_apply() {
  local changes
  changes=$(dotfiles_status)
  section "Dotfiles (chezmoi)"
  if [[ -z $changes ]]; then
    dotfiles_prune_stale
    ok "dotfiles already up to date"
    return 0
  fi

  ui_note "files that would change:"
  printf '%s\n' "$changes" | sed 's/^/    /' >&2

  if ((DRY_RUN)); then
    ui_note "[dry-run] chezmoi --source $DOTFILES_SRC apply"
    return 0
  fi

  # Safe by default: an existing differing file is never replaced silently.
  if ((! ASSUME_YES && ! ADOPT)); then
    if ! confirm "Apply these dotfile changes (existing files are backed up first)?"; then
      die "dotfiles not applied (user cancelled)" "$EX_CANCELLED"
    fi
  fi

  # A managed file the user deleted makes chezmoi ask "has changed since chezmoi
  # last wrote it?" on a TTY that does not exist under --yes. The file is gone,
  # so recreating it cannot overwrite anything: restore those targets with
  # --force, then apply the rest normally (a real local edit still stops here).
  local -a deleted=() modified=()
  local target
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    if [[ ${line:0:1} == D ]]; then
      # chezmoi only resolves absolute target arguments for `apply -- <target>`.
      target=$(trim "${line:2}")
      target=${target#\~/}
      [[ $target = /* ]] || target="$HOME/$target"
      deleted+=("$target")
    else
      modified+=("$line")
    fi
  done <<< "$changes"

  if ((${#deleted[@]})); then
    ui_note "restoring managed files that were removed: ${deleted[*]}"
    run_cmd chezmoi --source "$DOTFILES_SRC" apply --force -- "${deleted[@]}"
  fi
  if ((${#modified[@]})); then
    run_cmd chezmoi --source "$DOTFILES_SRC" apply
  fi

  # chezmoi status prints two status columns, a space, then the target path
  # (relative to $HOME, occasionally absolute).  # Directories that contain user data must never be recorded as managed:
  # uninstall would then be able to remove them wholesale.
  local protected=("$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME")
  local target p skip
  while IFS= read -r line; do
    target=$(printf '%s' "$line" | awk '{print $2}')
    [[ -n $target ]] || continue
    target=${target#\~/}
    [[ $target = /* ]] || target="$HOME/$target"
    skip=0
    for p in "${protected[@]}"; do
      [[ $target == "$p" ]] && skip=1
    done
    ((skip)) && continue
    record_managed "$target" chezmoi
  done <<< "$changes"

  dotfiles_prune_stale
}

shell_link() {
  local zshenv="$HOME/.zshenv"
  # Never overwrite: the loader is one clearly marked line the user owns.
  section "Shell loader"
  ui_note "Archway's zsh config lives in ~/.config/zsh and is loaded by ZDOTDIR."
  ui_note "add this line to ~/.zshenv:"
  # shellcheck disable=SC2016 # printed literally, for the user to paste
  ui_note '  export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"'

  if ((! LINK_SHELL)); then
    return 0
  fi
  if grep -q 'archway-zsh' "$zshenv" 2> /dev/null; then
    ok "zsh loader already present in $zshenv"
    return 0
  fi
  backup_file "$zshenv" || true
  if ((DRY_RUN)); then
    ui_note "[dry-run] append archway-zsh block to $zshenv"
    return 0
  fi
  # shellcheck disable=SC2016 # the literal expansion belongs in the user's file
  printf '\n# archway-zsh: managed by Archway, safe to remove\nexport ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"\n' >> "$zshenv"
  ok "zsh loader written to $zshenv"
}

security_notice() {
  [[ $(profile_get "$1" security_profile) == yes ]] || return 0
  section "Security profile — legal notice"
  cat >&2 << 'EOF'
  Archway installs dual-use security tooling. Use it only on systems you own,
  on CTFs/labs, or for clients with written authorisation. Archway does not
  configure attacks, persistence, exfiltration or exposed services.
EOF
  if ((DRY_RUN)); then
    ui_note "[dry-run] would require the phrase 'authorized' here"
    return 0
  fi
  confirm_phrase "authorized" "Type 'authorized' to confirm you have authorisation:" ||
    die "security profile declined" "$EX_CANCELLED"
}

# Hyprland and waybar start without ~/.local/bin on PATH, so a bind that calls
# `archway` fails silently while `kitty` works. Everything generated therefore
# uses this absolute link, which install keeps pointing at the checkout.
install_cli_links() {
  local dir="$HOME/.local/bin" name target link spec
  local -a pairs=("archway:bin/archway" "archway-bar:applets/bar/bar.sh")
  if ((DRY_RUN)); then
    for spec in "${pairs[@]}"; do
      ui_note "[dry-run] would link $dir/${spec%%:*}"
    done
    return 0
  fi
  mkdir -p -- "$dir"
  for spec in "${pairs[@]}"; do
    name=${spec%%:*}
    target="$ARCHWAY_ROOT/${spec#*:}"
    link="$dir/$name"
    if [[ -L $link || ! -e $link ]]; then
      ln -sfn -- "$target" "$link"
    else
      warn "$link exists and is not a symlink; leaving it alone"
    fi
  done
  ok "linked archway and archway-bar into $dir"
}

cmd_install() {
  parse_common_flags "$@"
  local profile='' wm='' terminal='' shell='' theme='' editor='' dry_requested=0
  local skip_packages=0 skip_dotfiles=0 skip_nvim=0
  ADOPT=0
  LINK_SHELL=0

  # Flags that take a value consume two entries; `continue` prevents the
  # trailing single shift from leaving the value behind as a positional.
  while ((${#ARGS[@]})); do
    case ${ARGS[0]} in
      help)
        install_help
        return 0
        ;;
      --profile)
        profile=$(need_value --profile "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --wm)
        wm=$(need_value --wm "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --terminal)
        terminal=$(need_value --terminal "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --shell)
        shell=$(need_value --shell "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --theme)
        theme=$(need_value --theme "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --editor)
        editor=$(need_value --editor "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --adopt) ADOPT=1 ;;
      --link-shell) LINK_SHELL=1 ;;
      --no-nvim) skip_nvim=1 ;;
      --no-packages) skip_packages=1 ;;
      --no-dotfiles) skip_dotfiles=1 ;;
      --fresh) ADOPT=1 ;;
      *) die "install: unexpected argument '${ARGS[0]}'" "$EX_USAGE" ;;
    esac
    ARGS=("${ARGS[@]:1}")
  done

  ((DRY_RUN)) && dry_requested=1
  if is_production_host && ((! APPLY_PRODUCTION)) && ((! DRY_RUN)); then
    warn "this is a production host ($(host_name)); install is forced to --dry-run."
    warn "pass --apply-production to override explicitly."
    DRY_RUN=1
  fi

  preflight_checks
  profile=${profile:-developer}
  profile_exists "$profile" || die "unknown profile: $profile (see 'archway install --help')" "$EX_USAGE"

  theme=${theme:-$(profile_get "$profile" theme)}
  editor=${editor:-$(profile_get "$profile" editor)}
  wm=${wm:-$(profile_get "$profile" wm)}
  terminal=${terminal:-$(profile_get "$profile" terminal)}
  shell=${shell:-$(profile_get "$profile" shell)}

  if [[ $wm != hyprland ]]; then
    die "unsupported compositor '$wm': Hyprland is the only first-class desktop (AGENTS.md ADR-002)" "$EX_USAGE"
  fi
  if have hyprctl; then
    local compat_status compat_detail
    IFS=$'\t' read -r compat_status compat_detail < <(compat_check hyprland)
    [[ $compat_status == ok ]] || warn "$compat_detail"
  fi

  theme_exists "$theme" || die "unknown theme: $theme" "$EX_USAGE"
  theme_validate "$theme" || die "theme '$theme' failed validation; fix the palette before installing" "$EX_PREFLIGHT"
  keys_validate > /dev/null || die "keybinds are invalid; run 'archway keys validate'" "$EX_PREFLIGHT"

  ui_header "Archway install plan"
  preflight_summary
  ui_kv "profile" "$profile"
  ui_kv "wm / terminal / shell" "$wm / $terminal / $shell"
  ui_kv "editor" "$editor"
  ui_kv "theme" "$theme"
  ui_kv "mode" "$([[ $ADOPT == 1 ]] && echo adopt || echo safe) $([[ $DRY_RUN == 1 ]] && echo '(dry-run)')"
  package_install_plan "$profile"

  if ((! DRY_RUN)); then
    ui_header "Confirm"
    if ! confirm "Proceed with this plan?"; then
      die "install cancelled" "$EX_CANCELLED"
    fi
  fi

  security_notice "$profile"

  # Backups first: every path we may modify goes into one manifest.
  section "Backup"
  local path
  while IFS= read -r path; do
    backup_file "$path" || true
  done < <(archway_config_paths)
  [[ -e $XDG_CONFIG_HOME/nvim ]] && backup_file "$XDG_CONFIG_HOME/nvim" || true
  [[ -e $XDG_CONFIG_HOME/archway ]] || backup_init
  if [[ -n $BACKUP_PATH ]]; then
    ui_kv "backup" "$BACKUP_PATH"
  else
    ui_note "nothing to back up on this host"
  fi

  if ((! skip_packages)); then
    section "Packages"
    if ((DRY_RUN)); then
      ui_note "[dry-run] see package plan above"
    else
      packages_install "$profile"
    fi
  else
    ui_note "packages skipped (--no-packages)"
  fi

  if ((! skip_dotfiles)); then
    dotfiles_apply
  else
    ui_note "dotfiles skipped (--no-dotfiles)"
  fi

  section "CLI"
  install_cli_links

  # The wallpaper applet reads user images; give them a known home. Nothing is
  # shipped or downloaded, so this is just an empty directory.
  if ((! DRY_RUN)); then
    mkdir -p -- "$XDG_DATA_HOME/archway/wallpapers"
  fi

  section "Theme"
  # A broken Neovim theme contract must not cancel the desktop (AGENTS.md
  # §7.2/§9.5): finish the install, report it, and exit non-zero at the end.
  local theme_failed=0
  theme_set "$theme" || theme_failed=1

  section "Shell"
  shell_link

  if [[ $editor == neovim ]] && ((! skip_nvim)); then
    section "Neovim"
    if nvim_lock_verified; then
      nvim_install || warn "Neovim step failed; the desktop is unaffected (see 'archway nvim doctor')"
    else
      warn "Neovim pin is a placeholder; skipping Neovim."
      warn "Run 'archway nvim pin <tag>' first, then 'archway nvim install'."
    fi
  fi

  section "Doctor"
  doctor_run || warn "doctor reported critical issues; review before using the session"

  if ((! DRY_RUN)); then
    ensure_dirs "$STATE_DIR" "$CONFIG_DIR"
    state_set "$STATE_FILE" version "$(archway_version)"
    state_set "$STATE_FILE" commit "$(archway_commit)"
    state_set "$STATE_FILE" channel "stable"
    state_set "$STATE_FILE" installed_at "$(now_iso)"
    state_set "$PROFILE_STATE_FILE" profile "$profile"
  fi

  ui_header "Next steps"
  ui_item "log out and pick the Hyprland session (started through uwsm)"
  ui_item "Super + / shows every keybind"
  ui_item "hyprctl reload applies config changes without ending the session"
  ui_item "archway update keeps this machine current (no re-clone)"
  ui_item "archway rollback restores the last backup"
  ((dry_requested)) && ui_note "this was a dry-run: nothing was written"

  if ((theme_failed)); then
    err "the desktop is installed, but Neovim did not get the theme"
    err "see 'archway doctor' and AGENTS.md §9.5 for the required upstream hook"
    return "$EX_FAIL"
  fi
  return 0
}

install_help() {
  cat << 'EOF'
archway install — install or reconcile the desktop

Usage:
  archway install [options]

Options:
  --profile <minimal|developer|security|full>   default: developer
  --wm <hyprland>                               only Hyprland is supported (ADR-002)
  --terminal <kitty|ghostty|wezterm|alacritty>  default: from the profile
  --shell <zsh|fish|bash>                       default: from the profile
  --theme <id>                                  default: android-mount
  --editor <neovim|helix|none>                  default: neovim
  --adopt            treat existing configs as replaceable (after backup)
  --link-shell       append the ZDOTDIR loader to ~/.zshenv (backup + consent)
  --no-nvim          skip Neovim entirely
  --no-packages      skip package installation
  --no-dotfiles      skip chezmoi apply
  --dry-run          print the plan; write nothing
  --yes              non-interactive (never implies --force)
  --apply-production allow writes on a host listed in production_hosts

Exit codes: 0 ok, 1 error, 2 usage, 3 preflight, 4 cancelled, 5 rollback.
EOF
}
