#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# commands.sh — theme, keys, backup, restore, rollback, pkg, nvim, version,
# uninstall and pin handlers.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_COMMANDS_LOADED:-} ]]; then return 0; fi
ARCHWAY_COMMANDS_LOADED=1

cmd_version() {
  parse_common_flags "$@"
  local profile theme nvim_commit
  profile=$(current_profile)
  theme=$(current_theme)
  nvim_commit=$(state_get "$NVIM_STATE_FILE" commit || printf 'none')

  if ((JSON_OUT)); then
    printf '{"name":"archway","version":%s,"codename":"Mount","commit":%s,"channel":%s,"host":%s,"profile":%s,"theme":%s,"nvim_commit":%s,"dry_run":%s}\n' \
      "$(json_str "$(archway_version)")" "$(json_str "$(archway_commit)")" \
      "$(json_str "$(archway_channel)")" "$(json_str "$(host_name)")" \
      "$(json_str "$profile")" "$(json_str "$theme")" "$(json_str "$nvim_commit")" \
      "$( ((DRY_RUN)) && echo true || echo false)"
    return 0
  fi

  printf 'archway %s (%s)\n' "$(archway_version)" "$(archway_commit)"
  ui_kv "codename" "Mount"
  ui_kv "channel" "$(archway_channel)"
  ui_kv "host" "$(host_name)"
  ui_kv "profile" "$profile"
  ui_kv "theme" "$theme"
  ui_kv "nvim" "$nvim_commit"
  ui_kv "state" "$STATE_DIR"
}

# ---------------------------------------------------------------- theme -----
cmd_theme() {
  parse_common_flags "$@"
  local sub=${ARGS[0]:-list}
  ARGS=("${ARGS[@]:1}")

  case $sub in
    list)
      local id
      for id in $(theme_list); do
        if [[ $id == "$(current_theme)" ]]; then
          printf '* %s\n' "$id"
        else
          printf '  %s\n' "$id"
        fi
      done
      ;;
    current)
      current_theme
      printf '\n'
      ;;
    set | preview)
      local id=${ARGS[0]:-}
      [[ -n $id ]] || die "usage: archway theme $sub <id>" "$EX_USAGE"
      if [[ $sub == preview ]]; then
        theme_preview "$id"
      else
        theme_set "$id"
      fi
      ;;
    validate)
      local id=${ARGS[0]:-android-mount}
      theme_validate "$id" || exit "$EX_FAIL"
      ;;
    render)
      local id=${ARGS[0]:-android-mount} dest=''
      ARGS=("${ARGS[@]:1}")
      while ((${#ARGS[@]})); do
        case ${ARGS[0]} in
          --to)
            dest=$(need_value --to "${ARGS[1]:-}")
            ARGS=("${ARGS[@]:2}")
            continue
            ;;
          *) die "theme render: unexpected argument '${ARGS[0]}'" "$EX_USAGE" ;;
        esac
        ARGS=("${ARGS[@]:1}")
      done
      [[ -n $dest ]] || dest="$CACHE_DIR/render/$id"
      ensure_dirs "$dest"
      theme_render "$id" "$dest"
      ;;
    nvim-contract)
      theme_nvim_contract "${ARGS[0]:-android-mount}"
      ;;
    help | *)
      cat << 'EOF'
archway theme — list, inspect, apply and validate themes

Usage:
  archway theme list
  archway theme current
  archway theme set <id>
  archway theme preview <id>
  archway theme validate [id]
  archway theme render <id> [--to <dir>]
  archway theme nvim-contract [id]

`set` renders every module into ~/.config/archway/theme.d/, records the choice
in ~/.config/archway/theme.toml and reloads running components. Neovim gets the
git-ignored lua/archway.lua hook only; tracked files are never edited.
EOF
      [[ $sub == help ]] || [[ -z $sub ]] || return 0
      ;;
  esac
}

# ----------------------------------------------------------------- keys -----
cmd_keys() {
  parse_common_flags "$@"
  local sub=${ARGS[0]:-list}
  ARGS=("${ARGS[@]:1}")

  case $sub in
    list | show) keys_list ;;
    search)
      [[ -n ${ARGS[0]:-} ]] || die "usage: archway keys search <text>" "$EX_USAGE"
      keys_search "${ARGS[0]}"
      ;;
    generate) keys_generate ;;
    validate) keys_validate || exit "$EX_FAIL" ;;
    check) keys_check || exit "$EX_FAIL" ;;
    help | *)
      cat << 'EOF'
archway keys — single-source keybinds

Usage:
  archway keys list
  archway keys search <text>
  archway keys generate     # writes the Hyprland binds + docs/keybinds.md
  archway keys validate     # duplicates, reserved chords, empty commands
  archway keys check        # are the generated files up to date? (CI)
EOF
      ;;
  esac
}

# --------------------------------------------------------------- applet -----
# Applets are separate scripts with their own --help, but keybinds should never
# hardcode an install path. `archway applet <name> [args...]` resolves them.
cmd_applet() {
  # Flags belong to the applet (--help, --dry-run, --json, --rofi), so nothing
  # is parsed here: `archway applet android-mount --help` must reach the script.
  local -a ARGS=("$@")
  local name=${ARGS[0]:-}
  if [[ -z $name || $name == help ]]; then
    printf 'usage: archway applet <name> [args...]\n\nAvailable:\n'
    local d
    for d in "$ARCHWAY_ROOT"/applets/*/; do
      [[ -f $d$(basename -- "$d").sh ]] && printf '  %s\n' "$(basename -- "$d")"
    done
    return 0
  fi
  local script="$ARCHWAY_ROOT/applets/$name/$name.sh"
  [[ -x $script ]] || die "unknown applet: $name" "$EX_USAGE"
  ARGS=("${ARGS[@]:1}")
  exec "$script" "${ARGS[@]}"
}

# --------------------------------------------------------------- backup -----
cmd_backup() {
  parse_common_flags "$@"
  local sub=${ARGS[0]:-create}
  case $sub in
    list)
      backup_list
      ;;
    create | *)
      require_not_root
      section "Backup"
      local path count=0
      while IFS= read -r path; do
        backup_file "$path" || true
        count=$((count + 1))
      done < <(archway_config_paths)
      if [[ -z $BACKUP_PATH ]]; then
        backup_init
        ui_note "no managed configuration found; created an empty backup set for the record"
      fi
      ok "$count path(s) considered; backup: ${BACKUP_PATH:-none (dry-run)}"
      ;;
  esac
}

cmd_restore() {
  parse_common_flags "$@"
  require_not_root
  local id=${ARGS[0]:-}
  if [[ -z $id ]]; then
    ui_header "Available backups"
    backup_list
    die "usage: archway restore <backup-id>" "$EX_USAGE"
  fi
  confirm "Restore backup '$id' over the current configuration?" ||
    die "restore cancelled" "$EX_CANCELLED"
  # Keep the current state recoverable: back up before overwriting.
  local p
  while IFS= read -r p; do
    backup_file "$p" || true
  done < <(archway_config_paths)
  restore_backup "$id"
}

cmd_rollback() {
  parse_common_flags "$@"
  require_not_root
  local latest
  latest=$(backup_latest) || die "no backups available" "$EX_FAIL"
  ui_header "Rollback"
  ui_kv "backup" "$(basename -- "$latest")"
  confirm "Restore the most recent backup?" || die "rollback cancelled" "$EX_CANCELLED"
  restore_backup "$latest"
  if [[ -d $ARCHWAY_ROOT/.git ]]; then
    local prev
    prev=$(state_get "$STATE_FILE" commit || true)
    if [[ -n $prev ]] && confirm "Also check out Archway commit $prev?"; then
      run_cmd git -C "$ARCHWAY_ROOT" checkout -- "$prev"
    fi
  fi
  exit "$EX_ROLLED_BACK"
}

# ------------------------------------------------------------------ pkg -----
cmd_pkg() {
  parse_common_flags "$@"
  local sub=${ARGS[0]:-list}
  ARGS=("${ARGS[@]:1}")

  case $sub in
    list)
      local profile
      for profile in $(profiles_list); do
        printf '\n%s\n' "$profile"
        package_install_plan "$profile"
      done
      ;;
    why)
      local pkg=${ARGS[0]:-}
      [[ -n $pkg ]] || die "usage: archway pkg why <package>" "$EX_USAGE"
      if pkg_why "$pkg"; then
        printf '%s appears in the manifests above. Profiles that include it:\n' "$pkg"
        local profile
        for profile in $(profiles_list); do
          profile_packages "$profile" | grep -qxF -- "$pkg" && printf '  - %s\n' "$profile"
        done
      else
        die "$pkg is not in any Archway manifest" "$EX_FAIL"
      fi
      ;;
    export)
      pkg_export "${ARGS[0]:-$PWD}"
      ;;
    check)
      pkg_check
      ;;
    help | *)
      cat << 'EOF'
archway pkg — inspect the package catalog

Usage:
  archway pkg list                 # profiles and their package counts
  archway pkg why <package>        # which manifests/profiles include it
  archway pkg export [dir]         # pacman -Qqen/-Qqem into dir
  archway pkg check                # verify official names against pacman
EOF
      ;;
  esac
}

# ----------------------------------------------------------------- nvim -----
cmd_nvim() {
  parse_common_flags "$@"
  local sub=${ARGS[0]:-status}
  ARGS=("${ARGS[@]:1}")

  case $sub in
    install) nvim_install ;;
    update)
      local to=''
      if [[ ${ARGS[0]:-} == --to ]]; then
        to=$(need_value --to "${ARGS[1]:-}")
      fi
      nvim_update "$to"
      ;;
    status) nvim_status ;;
    doctor) nvim_doctor ;;
    rollback) nvim_rollback ;;
    pin)
      nvim_pin "${ARGS[0]:-}"
      ;;
    help | *)
      cat << 'EOF'
archway nvim — pinned grubberdubber/nvim-config checkout

Usage:
  archway nvim pin <tag>          # resolve commit + tarball SHA256 into deps/nvim-config.lock
  archway nvim install
  archway nvim update [--to <tag>]
  archway nvim status [--json]
  archway nvim doctor
  archway nvim rollback

Archway never edits tracked Neovim files and never updates plugins outside
lazy-lock.json. Theme integration uses the local, git-ignored lua/archway.lua.
EOF
      ;;
  esac
}

# ------------------------------------------------------------------ pin -----
cmd_pin() {
  parse_common_flags "$@"
  require_not_root
  local version=${ARGS[0]:-}
  [[ -n $version ]] || die "usage: archway pin <version> (or --unpin)" "$EX_USAGE"
  if [[ $version == --unpin ]]; then
    state_delete "$STATE_FILE" pinned_version
    ok "version pin removed"
    return 0
  fi
  version=${version#v}
  ensure_dirs "$STATE_DIR"
  state_set "$STATE_FILE" pinned_version "$version"
  ok "pinned to v$version; 'archway update' will respect this pin"
}

# ------------------------------------------------------------- uninstall ----
cmd_uninstall() {
  parse_common_flags "$@"
  local restore=0 purge=0
  while ((${#ARGS[@]})); do
    case ${ARGS[0]} in
      --restore) restore=1 ;;
      --purge) purge=1 ;;
      help)
        cat << 'EOF'
archway uninstall — remove only what Archway manages

Usage:
  archway uninstall [--restore] [--purge]

  --restore   restore the most recent backup over managed paths
  --purge     also delete ~/.local/state/archway and ~/.config/archway

Packages are never removed by this command. Files Archway created in $HOME are
removed only when the backup manifest proves they did not exist before.
EOF
        return 0
        ;;
      *) die "uninstall: unexpected argument '${ARGS[0]}'" "$EX_USAGE" ;;
    esac
    ARGS=("${ARGS[@]:1}")
  done

  require_not_root
  ui_header "Uninstall"
  ui_kv "managed manifest" "$MANAGED_MANIFEST"
  local count=0
  [[ -r $MANAGED_MANIFEST ]] && count=$(wc -l < "$MANAGED_MANIFEST")
  ui_kv "managed paths" "$count"

  confirm_phrase "$(host_name)" "This removes Archway-managed files. Package removal is manual." ||
    die "uninstall cancelled" "$EX_CANCELLED"

  if ((restore)); then
    local latest
    if latest=$(backup_latest); then
      restore_backup "$latest"
    else
      warn "no backup to restore"
    fi
  fi

  # Remove only paths that did not exist before Archway installed them.
  local latest_manifest='' path found
  latest=$(backup_latest 2> /dev/null || true)
  if [[ -n $latest && -r $latest/manifest.tsv ]]; then
    latest_manifest="$latest/manifest.tsv"
  fi

  if [[ -r $MANAGED_MANIFEST ]]; then
    # Deepest paths first: files go before their (possibly shared) directories.
    while IFS=$'\t' read -r path _origin _ts; do
      [[ -n $path ]] || continue
      # Never touch anything outside $HOME, or the XDG roots themselves.
      case $path in
        "$HOME" | "$XDG_CONFIG_HOME" | "$XDG_DATA_HOME" | "$XDG_STATE_HOME" | "$XDG_CACHE_HOME")
          continue
          ;;
        "$HOME"/*) ;;
        *) continue ;;
      esac
      found=0
      if [[ -n $latest_manifest ]]; then
        cut -f1 "$latest_manifest" | grep -qxF -- "$path" && found=1
      fi
      if ((found)); then
        ui_note "kept (existed before Archway): $path"
      elif [[ -e $path || -L $path ]]; then
        if ((DRY_RUN)); then
          ui_note "[dry-run] would remove $path"
        elif [[ -d $path && ! -L $path ]]; then
          # rmdir refuses to delete a directory that still has content.
          if rmdir -- "$path" 2> /dev/null; then
            ui_note "removed $path"
          else
            ui_note "kept non-empty directory: $path"
          fi
        else
          rm -f -- "$path"
          ui_note "removed $path"
        fi
      fi
    done < <(sort -r -t$'\t' -k1,1 "$MANAGED_MANIFEST")
  fi

  local link="$HOME/.local/bin/archway"
  if [[ -L $link ]]; then
    if ((DRY_RUN)); then
      ui_note "[dry-run] would remove $link"
    else
      rm -f -- "$link"
      ok "removed $link"
    fi
  fi

  if ((purge)); then
    if ((DRY_RUN)); then
      ui_note "[dry-run] would remove $STATE_DIR and $CONFIG_DIR"
    else
      rm -rf -- "$STATE_DIR" "$CONFIG_DIR"
      ok "removed Archway state and configuration"
    fi
  fi

  ui_header "Uninstall complete"
  ui_item "packages were not removed: use pacman/paru as usual"
  ui_item "your own files and backups were preserved"
}
