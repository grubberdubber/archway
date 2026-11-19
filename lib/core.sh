#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# core.sh — strict-mode helpers, logging, flags, traps. Sourced by bin/archway.
# shellcheck shell=bash
# shellcheck disable=SC2034
# Exit-code constants and colour/flag globals are shared with lib/*.sh.

if [[ -n ${ARCHWAY_CORE_LOADED:-} ]]; then return 0; fi
ARCHWAY_CORE_LOADED=1

readonly EX_OK=0
readonly EX_FAIL=1
readonly EX_USAGE=2
readonly EX_PREFLIGHT=3
readonly EX_CANCELLED=4
readonly EX_ROLLED_BACK=5
readonly EX_DRIFT=10

DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_OUT=${JSON_OUT:-0}
APPLY_PRODUCTION=${APPLY_PRODUCTION:-0}
LOG_FILE=${LOG_FILE:-}

if [[ -t 2 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
  C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m' C_CYAN=$'\033[36m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

have() { command -v -- "$1" > /dev/null 2>&1; }

require_cmd() {
  local missing=() c
  for c in "$@"; do
    have "$c" || missing+=("$c")
  done
  if ((${#missing[@]})); then
    die "missing required command(s): ${missing[*]}" "$EX_PREFLIGHT"
  fi
}

require_not_root() {
  if ((EUID == 0)); then
    die "archway must not run as root. Run it as your user; sudo is only used for packages." "$EX_PREFLIGHT"
  fi
}

die() {
  local msg=$1 code=${2:-$EX_FAIL}
  printf '%sarchway: %s%s\n' "$C_RED" "$msg" "$C_RESET" >&2
  [[ -n $LOG_FILE ]] && printf 'ERROR: %s\n' "$msg" >> "$LOG_FILE" 2> /dev/null || true
  exit "$code"
}

_log() {
  local level=$1 color=$2 msg=$3
  local stamp
  stamp=$(printf '%(%H:%M:%S)T' -1)
  [[ -n $LOG_FILE ]] && printf '%s %-5s %s\n' "$stamp" "$level" "$msg" >> "$LOG_FILE" 2> /dev/null || true
  ((QUIET)) && [[ $level != ERROR ]] && return 0
  if ((JSON_OUT)) && [[ $level != ERROR ]]; then return 0; fi
  printf '%s%s%s %s\n' "$color" "$level" "$C_RESET" "$msg" >&2
}

info() { _log INFO "$C_BLUE" "$*"; }
ok() { _log OK "$C_GREEN" "$*"; }
warn() { _log WARN "$C_YELLOW" "$*"; }
err() { _log ERROR "$C_RED" "$*"; }
step() { _log STEP "$C_CYAN" "$*"; }
debug() {
  ((VERBOSE)) || return 0
  _log DEBUG "$C_DIM" "$*"
}

section() {
  ((QUIET)) && return 0
  printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET" >&2
}

cmd_string() {
  local out='' arg
  for arg in "$@"; do
    printf -v out '%s%q ' "$out" "$arg"
  done
  printf '%s' "${out% }"
}

run_cmd() {
  if ((DRY_RUN)); then
    printf '%s[dry-run]%s %s\n' "$C_YELLOW" "$C_RESET" "$(cmd_string "$@")" >&2
    return 0
  fi
  debug "exec: $(cmd_string "$@")"
  "$@"
}

confirm() {
  local prompt=${1:-"Continue?"}
  # A dry run only prints the plan, so it never needs consent.
  if ((DRY_RUN || ASSUME_YES)); then return 0; fi
  [[ -t 0 ]] || return 1
  local reply
  printf '%s%s%s [y/N] ' "$C_BOLD" "$prompt" "$C_RESET" >&2
  read -r reply || return 1
  [[ $reply =~ ^[yY]([eE][sS])?$ ]]
}

# Destructive/irreversible actions require typing an exact phrase.
confirm_phrase() {
  local phrase=$1 prompt=$2
  if ((DRY_RUN || ASSUME_YES)); then return 0; fi
  [[ -t 0 ]] || return 1
  local reply
  printf '%s%s%s\n  type %s%s%s to confirm: ' \
    "$C_BOLD" "$prompt" "$C_RESET" "$C_YELLOW" "$phrase" "$C_RESET" >&2
  read -r reply || return 1
  [[ $reply == "$phrase" ]]
}

now_iso() { printf '%(%Y-%m-%dT%H:%M:%S%z)T' -1; }
today_stamp() { printf '%(%Y%m%dT%H%M%S)T' -1; }
host_name() { printf '%s' "${HOSTNAME:-$(uname -n)}"; }

# JSON string escaping without jq (jq is only used for output shaping).
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

json_str() { printf '"%s"' "$(json_escape "$1")"; }

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

parse_common_flags() {
  ARGS=()
  while (($#)); do
    case $1 in
      --dry-run | -n) DRY_RUN=1 ;;
      --yes | -y) ASSUME_YES=1 ;;
      --verbose | -v) VERBOSE=1 ;;
      --quiet | -q) QUIET=1 ;;
      --json)
        JSON_OUT=1
        QUIET=1
        ;;
      --no-color) C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN='' ;;
      --apply-production) APPLY_PRODUCTION=1 ;;
      --help | -h) ARGS+=("help") ;;
      --)
        shift
        ARGS+=("$@")
        break
        ;;
      # Command-specific flags are validated by each handler.
      -*) ARGS+=("$1") ;;
      *) ARGS+=("$1") ;;
    esac
    shift
  done
}

need_value() {
  local flag=$1 value=${2:-}
  [[ -n $value ]] || die "$flag requires a value" "$EX_USAGE"
  printf '%s' "$value"
}

on_error() {
  local code=$1 line=$2 cmd=$3
  err "command failed (exit $code) at line $line: $cmd"
  [[ -n $LOG_FILE ]] && err "log: $LOG_FILE"
}

install_traps() {
  trap 'on_error $? "$LINENO" "$BASH_COMMAND"' ERR
  trap 'exit 130' INT
  trap 'exit 143' TERM
}
