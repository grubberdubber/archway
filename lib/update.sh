#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# update.sh — self-updating checkout (ADR-009).
#
# One checkout per machine. `git fetch` + fast-forward, then `chezmoi apply`,
# which only rewrites files whose content actually differs. No re-clone, no
# reinstall, local overrides preserved.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_UPDATE_LOADED:-} ]]; then return 0; fi
ARCHWAY_UPDATE_LOADED=1

checkout_clean() {
  [[ -d $ARCHWAY_ROOT/.git ]] || return 1
  [[ -z $(git -C "$ARCHWAY_ROOT" status --porcelain) ]]
}

checkout_ref() {
  git -C "$ARCHWAY_ROOT" rev-parse --short HEAD 2> /dev/null || printf 'unknown'
}

latest_stable_tag() {
  git -C "$ARCHWAY_ROOT" tag --list 'v*' --sort=-v:refname | head -n1
}

update_target() {
  local channel=$1 pinned=$2 to=$3
  if [[ -n $to ]]; then
    printf '%s' "$to"
    return 0
  fi
  if [[ -n $pinned ]]; then
    printf 'v%s' "${pinned#v}"
    return 0
  fi
  case $channel in
    edge) printf '%s' 'origin/main' ;;
    stable)
      local tag
      tag=$(latest_stable_tag)
      [[ -n $tag ]] || die "no stable tags found; use --channel edge or --to <ref>" "$EX_PREFLIGHT"
      printf '%s' "$tag"
      ;;
    *) die "unknown channel: $channel (stable|edge)" "$EX_USAGE" ;;
  esac
}

cmd_update() {
  parse_common_flags "$@"
  local check_only=0 to='' channel='' offline=0 no_snapshot=0
  while ((${#ARGS[@]})); do
    case ${ARGS[0]} in
      help)
        update_help
        return 0
        ;;
      --check) check_only=1 ;;
      --to)
        to=$(need_value --to "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --channel)
        channel=$(need_value --channel "${ARGS[1]:-}")
        ARGS=("${ARGS[@]:2}")
        continue
        ;;
      --offline) offline=1 ;;
      --no-snapshot) no_snapshot=1 ;;
      *) die "update: unexpected argument '${ARGS[0]}'" "$EX_USAGE" ;;
    esac
    ARGS=("${ARGS[@]:1}")
  done

  require_not_root
  [[ -d $ARCHWAY_ROOT/.git ]] || die "$ARCHWAY_ROOT is not a git checkout" "$EX_PREFLIGHT"
  require_cmd git
  channel=${channel:-$(archway_channel)}
  local pinned
  pinned=$(state_get "$STATE_FILE" pinned_version || true)

  local before
  before=$(checkout_ref)
  ui_header "Archway update"
  ui_kv "checkout" "$ARCHWAY_ROOT"
  ui_kv "current" "$before"
  ui_kv "channel" "$channel"

  if ((offline)); then
    ui_kv "network" "offline (no fetch)"
  else
    info "fetching tags"
    run_cmd git -C "$ARCHWAY_ROOT" fetch --tags --prune origin
  fi

  local target
  target=$(update_target "$channel" "$pinned" "$to")
  local target_ref=''
  if git -C "$ARCHWAY_ROOT" rev-parse --verify --quiet "$target" > /dev/null; then
    target_ref=$(git -C "$ARCHWAY_ROOT" rev-parse --short "$target")
  fi
  ui_kv "target" "$target ${target_ref:+($target_ref)}"

  if [[ $before == "$target_ref" && -n $target_ref ]]; then
    ok "already up to date"
    return 0
  fi

  if ((check_only)); then
    info "update available: $target"
    printf '%s\n' "$target"
    return "$EX_DRIFT"
  fi

  # Local edits are the user's work: never reset them away.
  if ! checkout_clean; then
    err "the checkout has local changes; refusing to update."
    git -C "$ARCHWAY_ROOT" status --short >&2 || true
    err "commit/stash them, or run 'archway diff' to inspect."
    return "$EX_PREFLIGHT"
  fi

  if ((! no_snapshot)); then
    if command -v snapper > /dev/null 2>&1 && command -v btrfs > /dev/null 2>&1; then
      ui_note "Btrfs detected: create a pre-update snapshot yourself if you need one"
      ui_note "(Archway will not guess your snapper config)"
    fi
  fi

  section "Backup"
  local path
  while IFS= read -r path; do
    backup_file "$path" || true
  done < <(archway_config_paths)

  if ((DRY_RUN)); then
    ui_note "[dry-run] git merge --ff-only $target; migrations; chezmoi apply; doctor"
    return 0
  fi

  section "Fast-forward"
  if ! run git -C "$ARCHWAY_ROOT" merge --ff-only "$target"; then
    err "cannot fast-forward to $target; the checkout diverged."
    err "Resolve it manually; Archway does not rewrite history."
    return "$EX_PREFLIGHT"
  fi

  if ! migrations_run; then
    err "migration failed; restoring the pre-update backup"
    [[ -n $BACKUP_PATH && -d $BACKUP_PATH ]] && restore_backup "$BACKUP_PATH" || true
    return "$EX_FAIL"
  fi

  dotfiles_apply || {
    err "chezmoi apply failed; run 'archway rollback'"
    return "$EX_FAIL"
  }

  local theme
  theme=$(current_theme)
  if [[ $theme != none && -d $THEME_D_DIR ]]; then
    theme_set "$theme" || warn "theme re-render reported a problem"
  fi

  if [[ -d $XDG_CONFIG_HOME/nvim/.git ]] && nvim_lock_verified; then
    nvim_install || warn "Neovim update failed; desktop unaffected (archway nvim rollback)"
  fi

  section "Doctor"
  if ! doctor_run; then
    err "doctor found critical issues after update; rolling back"
    if [[ -n $BACKUP_PATH && -d $BACKUP_PATH ]]; then
      restore_backup "$BACKUP_PATH" || true
    fi
    run_cmd git -C "$ARCHWAY_ROOT" checkout -- "$before" || true
    return "$EX_ROLLED_BACK"
  fi

  if ((! DRY_RUN)); then
    state_set "$STATE_FILE" version "$(archway_version)"
    state_set "$STATE_FILE" commit "$(archway_commit)"
    state_set "$STATE_FILE" channel "$channel"
    state_set "$STATE_FILE" updated_at "$(now_iso)"
  fi
  ok "updated to $(archway_version) ($(archway_commit))"
  return 0
}

update_help() {
  cat << 'EOF'
archway update — update this machine without re-cloning

Usage:
  archway update [options]

Options:
  --check             only report whether an update exists (exit 10 if yes)
  --to <ref>          fast-forward to a specific tag/commit
  --channel <c>       stable (default, newest v* tag) or edge (origin/main)
  --offline           skip git fetch (use refs already on disk)
  --no-snapshot       skip the snapshot reminder
  --dry-run           show what would happen; change nothing

Flow: clean-check -> backup -> fast-forward -> migrations -> chezmoi apply
      -> theme re-render -> Neovim -> doctor -> rollback on critical failure.
EOF
}
