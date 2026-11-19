#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# nvim.sh — pinned checkout of grubberdubber/nvim-config (AGENTS.md §9.5).
# Archway never forks, vendors, edits tracked files or updates plugins outside
# lazy-lock.json.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_NVIM_LOADED:-} ]]; then return 0; fi
ARCHWAY_NVIM_LOADED=1

NVIM_LOCK="$ARCHWAY_ROOT/deps/nvim-config.lock"
NVIM_DIR="$XDG_CONFIG_HOME/nvim"
NVIM_MIN_VERSION_DEFAULT="0.12.5"

lock_get() {
  local key=$1
  [[ -r $NVIM_LOCK ]] || return 1
  local line
  line=$(grep -m1 -E "^${key}[[:space:]]*=" "$NVIM_LOCK") || return 1
  line=${line#*=}
  line=$(trim "$line")
  line=${line#\"}
  line=${line%\"}
  printf '%s' "$line"
}

nvim_lock_present() { [[ -n $(lock_get commit) ]]; }
nvim_lock_verified() {
  nvim_lock_present || return 1
  [[ $(lock_get unpinned) == "true" ]] && return 1
  [[ $(lock_get sha256) =~ ^[0-9a-f]{64}$ ]] || return 1
  [[ $(lock_get commit) =~ ^[0-9a-f]{40}$ ]] || return 1
}

version_ge() {
  # version_ge 0.12.5 0.12.4 -> true
  [[ $(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1) == "$2" ]]
}

nvim_binary_version() {
  have nvim || return 1
  nvim --version 2> /dev/null | head -n1 | sed -E 's/^NVIM v?//; s/[[:space:]].*$//'
}

nvim_requirements() {
  local -a missing=()
  local min
  min=$(lock_get tested_neovim || printf '%s' "$NVIM_MIN_VERSION_DEFAULT")
  [[ -n $min ]] || min=$NVIM_MIN_VERSION_DEFAULT

  local v
  if ! v=$(nvim_binary_version); then
    missing+=("neovim (not installed)")
  elif ! version_ge "$v" "$min"; then
    missing+=("neovim >= $min (found $v)")
  fi

  local tool
  for tool in git make cargo rg fd node tree-sitter; do
    have "$tool" || missing+=("$tool")
  done

  if ((${#missing[@]})); then
    warn "Neovim prerequisites missing:"
    local m
    for m in "${missing[@]}"; do ui_item "$m"; done
    return 1
  fi
  debug "Neovim prerequisites satisfied"
  return 0
}

nvim_checkout_clean() {
  [[ -d $NVIM_DIR/.git ]] || return 1
  [[ -z $(git -C "$NVIM_DIR" status --porcelain) ]]
}

nvim_status() {
  local installed='none' commit='' clean='n/a' theme='none'
  if [[ -d $NVIM_DIR/.git ]]; then
    installed='git checkout'
    commit=$(git -C "$NVIM_DIR" rev-parse --short HEAD 2> /dev/null || printf '?')
    if nvim_checkout_clean; then clean='clean'; else clean='dirty'; fi
  elif [[ -d $NVIM_DIR ]]; then
    installed='directory (not a git checkout)'
  fi
  local hook
  hook=$(theme_nvim_hook_target)
  [[ -f $hook ]] && theme=$(sed -n 's/.*theme = "\([^"]*\)".*/\1/p' "$hook" | head -n1)

  if ((JSON_OUT)); then
    printf '{"lock":%s,"pinned":%s,"tag":%s,"commit":%s,"url":%s,"installed":%s,"checkout_commit":%s,"clean":%s,"theme":%s,"nvim_version":%s}\n' \
      "$(json_str "$NVIM_LOCK")" \
      "$(nvim_lock_verified && echo true || echo false)" \
      "$(json_str "$(lock_get tag || true)")" \
      "$(json_str "$(lock_get commit || true)")" \
      "$(json_str "$(lock_get url || true)")" \
      "$(json_str "$installed")" "$(json_str "$commit")" "$(json_str "$clean")" \
      "$(json_str "$theme")" "$(json_str "$(nvim_binary_version || echo missing)")"
    return 0
  fi
  ui_kv "lock" "$NVIM_LOCK"
  ui_kv "pinned" "$(nvim_lock_verified && echo yes || echo 'no (run archway nvim pin <tag>)')"
  ui_kv "tag" "$(lock_get tag || echo -)"
  ui_kv "commit" "$(lock_get commit || echo -)"
  ui_kv "installed" "$installed"
  ui_kv "checkout" "${commit:-none}"
  ui_kv "clean" "$clean"
  ui_kv "theme hook" "$theme"
  ui_kv "nvim" "$(nvim_binary_version || echo missing)"
}

# Resolve a tag against upstream and record commit + tarball SHA256.
nvim_pin() {
  local tag=$1 url tarball tmp commit sha
  [[ -n $tag ]] || die "usage: archway nvim pin <tag>" "$EX_USAGE"
  require_cmd git curl sha256sum
  url=$(lock_get url)
  [[ -n $url ]] || die "lock file has no url: $NVIM_LOCK" "$EX_FAIL"

  info "resolving $url tag $tag"
  commit=$(git ls-remote --tags --refs "$url" "refs/tags/$tag^{}" 2> /dev/null | awk '{print $1}')
  if [[ -z $commit ]]; then
    commit=$(git ls-remote --tags --refs "$url" "refs/tags/$tag" 2> /dev/null | awk '{print $1}')
  fi
  [[ -n $commit ]] || die "tag '$tag' not found upstream in $url" "$EX_PREFLIGHT"
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || die "unexpected commit format: $commit" "$EX_FAIL"

  local repo_path=${url#https://github.com/}
  repo_path=${repo_path%.git}
  local tarball_url="https://github.com/${repo_path}/archive/refs/tags/${tag}.tar.gz"

  tmp=$(mktemp -d)
  tarball="$tmp/nvim-config.tar.gz"
  info "downloading release tarball to verify its checksum"
  run_cmd curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
    -o "$tarball" "$tarball_url" ||
    die "could not download the tarball for tag $tag" "$EX_PREFLIGHT"
  sha=$(sha256sum -- "$tarball" | cut -d' ' -f1)
  rm -rf -- "$tmp"

  if ((DRY_RUN)); then
    ui_note "[dry-run] would pin tag=$tag commit=$commit sha256=$sha"
    return 0
  fi

  local tested
  tested=$(lock_get tested_neovim || printf '%s' "$NVIM_MIN_VERSION_DEFAULT")
  cat > "$NVIM_LOCK" << EOF
# Pinned Neovim configuration consumed by Archway (AGENTS.md §9.5).
# Generated by \`archway nvim pin $tag\` on $(now_iso). Do not edit by hand.

schema = 1
url = "$url"
tag = "$tag"
commit = "$commit"
sha256 = "$sha"
tested_neovim = "${tested:-$NVIM_MIN_VERSION_DEFAULT}"
channel = "stable"
unpinned = false
EOF
  ok "pinned $tag ($commit)"
  ok "remember to update deps/nvim-config.lock in the Archway release commit"
}

nvim_backup_existing() {
  [[ -e $NVIM_DIR ]] || return 0
  section "Existing Neovim configuration detected"
  if [[ -d $NVIM_DIR/.git ]] && [[ $(git -C "$NVIM_DIR" remote get-url origin 2> /dev/null || true) == *nvim-config* ]]; then
    ui_note "it is already the pinned checkout; Archway will adopt it"
    return 0
  fi
  ui_kv "path" "$NVIM_DIR"
  if ! confirm "Back up and move aside the existing Neovim config?"; then
    die "aborted: existing Neovim config left untouched" "$EX_CANCELLED"
  fi
  backup_file "$NVIM_DIR" || true
  if ((! DRY_RUN)); then
    local aside
    aside="$STATE_DIR/backups/${BACKUP_ID}/moved/nvim"
    mkdir -p -- "$(dirname -- "$aside")"
    mv -- "$NVIM_DIR" "$aside"
    record_managed "$NVIM_DIR" nvim
    ui_note "moved aside to: $aside"
  fi
}

nvim_install() {
  nvim_lock_verified || die "Neovim pin is not verified. Run: archway nvim pin <tag>" "$EX_PREFLIGHT"
  nvim_requirements || die "Neovim prerequisites are not satisfied" "$EX_PREFLIGHT"

  local url commit
  url=$(lock_get url)
  commit=$(lock_get commit)

  if [[ -d $NVIM_DIR/.git ]] && [[ $(git -C "$NVIM_DIR" remote get-url origin 2> /dev/null || true) == *nvim-config* ]]; then
    nvim_checkout_clean || die "Neovim checkout has local changes; commit or stash them first" "$EX_PREFLIGHT"
    info "reusing existing nvim-config checkout"
  else
    nvim_backup_existing
    if ((DRY_RUN)); then
      ui_note "[dry-run] would clone $url into $NVIM_DIR and checkout $commit"
      return 0
    fi
    ensure_dirs "$(dirname -- "$NVIM_DIR")"
    run_cmd git clone --filter=blob:none --no-checkout -- "$url" "$NVIM_DIR"
  fi

  local previous=''
  previous=$(git -C "$NVIM_DIR" rev-parse HEAD 2> /dev/null || true)

  run_cmd git -C "$NVIM_DIR" fetch --tags --prune origin
  run_cmd git -C "$NVIM_DIR" checkout -- "$commit"

  local actual
  actual=$(git -C "$NVIM_DIR" rev-parse HEAD 2> /dev/null || true)
  if ((! DRY_RUN)) && [[ $actual != "$commit" ]]; then
    die "checkout is at $actual, expected $commit" "$EX_FAIL"
  fi

  # Bootstrap must not re-run pacman. Prefer --skip-packages when upstream has it.
  if [[ -f $NVIM_DIR/bootstrap.sh ]]; then
    if grep -q -- '--skip-packages' "$NVIM_DIR/bootstrap.sh" 2> /dev/null; then
      run_cmd bash "$NVIM_DIR/bootstrap.sh" --skip-packages
    elif ((ASSUME_YES)); then
      die "bootstrap.sh has no --skip-packages; refusing to run package installs with --yes" "$EX_PREFLIGHT"
    else
      warn "bootstrap.sh does not support --skip-packages."
      warn "It may re-sync pacman or install extra packages (including firefox)."
      if ! confirm_phrase "run-bootstrap" "Run the upstream bootstrap anyway?"; then
        die "bootstrap skipped by user; Neovim may be incomplete" "$EX_CANCELLED"
      fi
      run_cmd bash "$NVIM_DIR/bootstrap.sh"
    fi
  else
    warn "no bootstrap.sh found in $NVIM_DIR; skipping"
  fi

  nvim_validate || die "Neovim validation failed; run 'archway nvim rollback'" "$EX_FAIL"

  if ((! DRY_RUN)); then
    state_set "$NVIM_STATE_FILE" commit "$commit"
    state_set "$NVIM_STATE_FILE" tag "$(lock_get tag || true)"
    state_set "$NVIM_STATE_FILE" installed_at "$(now_iso)"
    state_set "$NVIM_STATE_FILE" theme "$(current_theme)"
    [[ -n $previous && $previous != "$commit" ]] && state_set "$NVIM_STATE_FILE" previous_commit "$previous"
    record_managed "$NVIM_DIR" nvim
  fi
  ok "Neovim installed at $commit"

  local theme
  theme=$(current_theme)
  [[ $theme != none ]] && theme_nvim_sync "$theme" || true
}

nvim_validate() {
  ((DRY_RUN)) && {
    ui_note "[dry-run] would run Lazy! restore and checkhealth"
    return 0
  }
  require_cmd nvim
  local start end ms

  info "restoring plugins from lazy-lock.json"
  if ! nvim --headless "+Lazy! restore" +qa > /dev/null 2>&1; then
    err "Lazy restore failed"
    return 1
  fi
  info "running checkhealth"
  if ! nvim --headless "+checkhealth" +qa > /dev/null 2>&1; then
    warn "checkhealth reported problems; inspect with 'archway nvim doctor'"
  fi
  start=$(date +%s%N)
  nvim --headless +qa > /dev/null 2>&1 || true
  end=$(date +%s%N)
  ms=$(((end - start) / 1000000))
  ok "Neovim cold start: ${ms} ms"
  ((ms < 1000)) || warn "Neovim start is ${ms} ms; the target is milliseconds, not seconds"
}

nvim_update() {
  local to=${1:-}
  [[ -n $to ]] && nvim_pin "$to"
  nvim_install
}

nvim_rollback() {
  local previous
  previous=$(state_get "$NVIM_STATE_FILE" previous_commit || true)
  if [[ -z $previous ]]; then
    die "no previous Neovim commit recorded" "$EX_FAIL"
  fi
  confirm "Roll Neovim back to $previous?" || die "cancelled" "$EX_CANCELLED"
  run_cmd git -C "$NVIM_DIR" checkout -- "$previous"
  ok "Neovim rolled back to $previous"
}

nvim_doctor() {
  local rc=0
  section "Neovim"
  if nvim_lock_verified; then
    ok "pin verified ($(lock_get tag))"
  else
    warn "pin is a placeholder or unverified: run 'archway nvim pin <tag>'"
    rc=1
  fi
  if nvim_requirements; then ok "prerequisites satisfied"; else rc=1; fi
  if [[ -d $NVIM_DIR/.git ]]; then
    if nvim_checkout_clean; then ok "checkout clean"; else
      err "checkout has local changes"
      rc=1
    fi
    local hook
    hook=$(theme_nvim_hook_target)
    if [[ -f $hook ]]; then ok "theme hook present"; else warn "theme hook missing (archway theme set)"; fi
  else
    warn "Neovim is not installed at $NVIM_DIR"
  fi
  return "$rc"
}
