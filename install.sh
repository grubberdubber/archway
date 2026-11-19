#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Archway bootstrap — auditable, versioned, idempotent.
#
# This script is meant to be read and then run from a checkout or a verified
# release asset. It never pipes a remote script into a shell, never uses sudo,
# and never writes dotfiles itself: it prepares a single checkout, links the
# CLI, and hands over to `archway install` (which plans first).
set -Eeuo pipefail

REPO_URL="${ARCHWAY_REPO:-https://github.com/grubberdubber/archway}"
REF="${ARCHWAY_REF:-main}"
PREFIX="${ARCHWAY_PREFIX:-$HOME/.local}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/archway"
SRC_DIR="$DATA_DIR/src"
DRY_RUN=0

usage() {
  cat << 'EOF'
Archway bootstrap

Usage:
  ./install.sh [--repo <url>] [--ref <tag|branch>] [--prefix <dir>] [--dry-run]

Options:
  --repo <url>    repository to install from (default: ARCHWAY_REPO or GitHub)
  --ref <ref>     tag or branch (default: main; releases should pass a tag)
  --prefix <dir>  where to link the CLI (default: ~/.local)
  --dry-run       print every command; change nothing

Requirements: bash >= 5.2, git, curl (only for the optional tarball check).
Packages are installed later by `archway install`, which asks once for sudo.
EOF
}

log() { printf '\033[36m[bootstrap]\033[0m %s\n' "$*"; }
die() {
  printf '\033[31m[bootstrap] %s\033[0m\n' "$1" >&2
  exit "${2:-1}"
}

run() {
  if ((DRY_RUN)); then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

main() {
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --repo)
        REPO_URL=${2:?--repo needs a value}
        shift
        ;;
      --ref)
        REF=${2:?--ref needs a value}
        shift
        ;;
      --prefix)
        PREFIX=${2:?--prefix needs a value}
        shift
        ;;
      --dry-run) DRY_RUN=1 ;;
      *) die "unknown argument: $1" 2 ;;
    esac
    shift
  done

  ((EUID == 0)) && die "do not run the bootstrap as root" 2
  command -v git > /dev/null 2>&1 || die "git is required" 3
  [[ -f /etc/arch-release ]] || log "warning: this does not look like Arch Linux"

  log "checkout: $SRC_DIR"
  if [[ -d $SRC_DIR/.git ]]; then
    log "existing checkout found; fetching $REF"
    run git -C "$SRC_DIR" fetch --tags --prune origin
  else
    run mkdir -p -- "$DATA_DIR"
    run git clone --filter=blob:none -- "$REPO_URL" "$SRC_DIR"
  fi

  run git -C "$SRC_DIR" checkout -- "$REF"

  local link="$PREFIX/bin/archway"
  run mkdir -p -- "$PREFIX/bin"
  if [[ -L $link ]]; then
    log "refreshing $link"
    run ln -sfn -- "$SRC_DIR/bin/archway" "$link"
  elif [[ -e $link ]]; then
    die "$link exists and is not a symlink; move it away first"
  else
    run ln -s -- "$SRC_DIR/bin/archway" "$link"
  fi

  if ((DRY_RUN)); then
    log "dry-run: would now run 'archway install --dry-run'"
    return 0
  fi

  log "handing over to the CLI (it will plan before writing anything)"
  exec "$SRC_DIR/bin/archway" install "$@"
}

main "$@"
