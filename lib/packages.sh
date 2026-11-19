#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# packages.sh — profiles and package manifests. Never installs silently.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_PACKAGES_LOADED:-} ]]; then return 0; fi
ARCHWAY_PACKAGES_LOADED=1

PROFILES_DIR="$ARCHWAY_ROOT/profiles"
PACKAGES_DIR="$ARCHWAY_ROOT/packages"

profiles_list() {
  local d
  for d in "$PROFILES_DIR"/*/; do
    [[ -f $d/profile.conf ]] || continue
    basename -- "$d"
  done
}

profile_exists() { [[ -f $PROFILES_DIR/$1/profile.conf ]]; }

# profile_get <profile> <key>
profile_get() {
  local profile=$1 key=$2
  profile_exists "$profile" || return 1
  local line
  line=$(grep -m1 -E "^${key}=" "$PROFILES_DIR/$profile/profile.conf" 2> /dev/null) || return 1
  printf '%s' "${line#*=}"
}

profile_manifests() {
  local profile=$1
  profile_get "$profile" manifests | tr ',' ' '
}

# Read a manifest, dropping comments and blank lines. Prints package names.
manifest_packages() {
  local id=$1
  local file="$PACKAGES_DIR/$id.txt"
  [[ -r $file ]] || die "unknown package manifest: $id" "$EX_PREFLIGHT"
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$file" | grep -v '^$' || true
}

profile_packages() {
  local profile=$1 manifest
  for manifest in $(profile_manifests "$profile"); do
    manifest_packages "$manifest"
  done | awk '!seen[$0]++'
}

profile_official() {
  local profile=$1 manifest
  for manifest in $(profile_manifests "$profile"); do
    [[ $manifest == aur-* ]] && continue
    manifest_packages "$manifest"
  done | awk '!seen[$0]++'
}

profile_aur() {
  local profile=$1 manifest
  for manifest in $(profile_manifests "$profile"); do
    [[ $manifest == aur-* ]] || continue
    manifest_packages "$manifest"
  done | awk '!seen[$0]++'
}

# Count occurrences of a package across all manifests (for `pkg why`).
pkg_why() {
  local needle=$1 file id found=0
  for file in "$PACKAGES_DIR"/*.txt; do
    id=$(basename -- "$file" .txt)
    if manifest_packages "$id" | grep -qxF -- "$needle"; then
      printf '%s\n' "$id"
      found=1
    fi
  done
  ((found)) || return 1
}

pkg_export() {
  local dest=${1:-$PWD}
  ensure_dirs "$dest"
  if ((DRY_RUN)); then
    ui_note "[dry-run] would export pacman -Qqen/-Qqem into $dest"
    return 0
  fi
  pacman -Qqen > "$dest/pkglist-official.txt"
  pacman -Qqem > "$dest/pkglist-aur.txt"
  ok "exported package lists to $dest"
}

# Verify every official package exists in core/extra/multilib ONLY. `pacman -Si`
# also matches chaotic-aur and blackarch when the developer has those repos
# enabled, which silently turns a broken official manifest into a green check.
pkg_check() {
  require_cmd pacman
  local missing=() p
  local -a pkgs=()
  local official_index repo
  official_index=$(mktemp)
  # Iterate repos individually: multilib is not configured in every container,
  # and one unavailable repo must not fail the whole check under pipefail.
  for repo in core extra multilib; do
    pacman -Sl "$repo" 2> /dev/null | awk '{print $2}' || true
  done | sort -u > "$official_index"

  mapfile -t pkgs < <(
    manifest_packages official-core
    manifest_packages official-desktop
    manifest_packages official-dev
    manifest_packages official-sec
    manifest_packages fonts
  )
  if ((${#pkgs[@]} == 0)); then
    warn "no packages found in manifests"
    rm -f -- "$official_index"
    return 0
  fi
  for p in "${pkgs[@]}"; do
    grep -qxF -- "$p" "$official_index" || missing+=("$p")
  done
  rm -f -- "$official_index"
  if ((${#missing[@]})); then
    err "not found in the official repositories: ${missing[*]}"
    return 1
  fi
  ok "all ${#pkgs[@]} official packages resolve"
}

package_install_plan() {
  local profile=$1
  local -a official=() aur=()
  mapfile -t official < <(profile_official "$profile")
  mapfile -t aur < <(profile_aur "$profile")
  ui_kv "official" "${#official[@]} packages"
  ui_kv "aur" "${#aur[@]} packages"
  if ((VERBOSE)); then
    printf '  %s\n' "${official[*]}"
    printf '  %s\n' "${aur[*]}"
  fi
}

# Install packages for a profile. Requires explicit consent; AUR is never
# installed with --noconfirm and PKGBUILDs are always reviewed by paru.
packages_install() {
  local profile=$1
  local -a official=() aur=()
  mapfile -t official < <(profile_official "$profile")
  mapfile -t aur < <(profile_aur "$profile")

  if ((${#official[@]})); then
    section "Official packages"
    if ((DRY_RUN)); then
      ui_note "[dry-run] sudo pacman -Syu && sudo pacman -S --needed ${official[*]}"
    else
      require_cmd sudo
      # A partial upgrade bricks Arch: always sync the whole system first.
      run_cmd sudo pacman -Syu
      run_cmd sudo pacman -S --needed -- "${official[@]}"
    fi
  fi

  if ((${#aur[@]})); then
    section "AUR packages"
    local helper=''
    for helper in paru yay; do
      have "$helper" && break
      helper=''
    done
    if [[ -z $helper ]]; then
      warn "no AUR helper found; skipping AUR packages: ${aur[*]}"
      warn "install paru (packages/aur-core.txt lists it) and re-run"
      return 0
    fi
    if ((DRY_RUN)); then
      ui_note "[dry-run] $helper -S --needed ${aur[*]} (no --noconfirm; review PKGBUILDs)"
    else
      run_cmd "$helper" -S --needed -- "${aur[@]}"
    fi
  fi
}
