#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# compat.sh — read desktops/hyprland/compat.toml and compare versions.
# shellcheck shell=bash

if [[ -n ${ARCHWAY_COMPAT_LOADED:-} ]]; then return 0; fi
ARCHWAY_COMPAT_LOADED=1

COMPAT_FILE="$ARCHWAY_ROOT/desktops/hyprland/compat.toml"

# compat_get <section> <key> -> value without quotes, empty when absent.
compat_get() {
  local section=$1 key=$2
  [[ -r $COMPAT_FILE ]] || return 0
  awk -v want_section="$section" -v want_key="$key" '
    /^[[:space:]]*\[/ {
      sect = $0
      gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", sect)
      in_section = (sect == want_section)
      next
    }
    in_section && $0 ~ ("^[[:space:]]*" want_key "[[:space:]]*=") {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/"/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$COMPAT_FILE"
}

# Installed version of a component we can query without a running session.
compat_installed() {
  local component=$1 out
  case $component in
    hyprland)
      have hyprctl || return 1
      out=$(hyprctl version 2> /dev/null | head -n1) || return 1
      [[ $out =~ ([0-9]+\.[0-9]+\.[0-9]+) ]] && printf '%s' "${BASH_REMATCH[1]}"
      ;;
    hyprlock | hypridle | hyprpaper)
      have "$component" || return 1
      out=$("$component" --version 2> /dev/null | head -n1) || return 1
      [[ $out =~ ([0-9]+\.[0-9]+\.[0-9]+) ]] && printf '%s' "${BASH_REMATCH[1]}"
      ;;
    *) return 1 ;;
  esac
}

# Emit "status<TAB>message" for the doctor. status: ok | warn | fail.
compat_check() {
  local component=${1:-hyprland}
  local minimum tested installed
  minimum=$(compat_get "$component" minimum)
  tested=$(compat_get "$component" tested)
  if [[ -z $minimum || -z $tested ]]; then
    printf 'warn\t%s: compat.toml has no bounds\n' "$component"
    return 0
  fi
  if ! installed=$(compat_installed "$component"); then
    printf 'warn\t%s not queryable (session not running?)\n' "$component"
    return 0
  fi
  if ! version_ge "$installed" "$minimum"; then
    printf 'fail\t%s %s is older than the supported minimum %s\n' "$component" "$installed" "$minimum"
  elif version_ge "$installed" "$tested"; then
    if [[ $installed == "$tested" ]]; then
      printf 'ok\t%s %s (tested)\n' "$component" "$installed"
    else
      printf 'warn\t%s %s is newer than the tested %s; expect config drift\n' \
        "$component" "$installed" "$tested"
    fi
  else
    printf 'ok\t%s %s (supported, tested %s)\n' "$component" "$installed" "$tested"
  fi
}
