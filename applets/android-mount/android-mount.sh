#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# android-mount — list, mount and unmount Android devices over MTP.
#
# Safety rules (AGENTS.md §9.3):
#   * never sudo, never a global /mnt path
#   * mount only under ~/Android_Mount/<slug>
#   * validate device indexes, sanitise names, never follow symlinks
#   * unmount with fusermount; remove the directory only when empty
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ROFI=0
MODE='list'
ARG=''

MOUNT_ROOT="$HOME/Android_Mount"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway"
STATE_FILE="$STATE_DIR/android-mount.tsv"

die() {
  printf 'android-mount: %s\n' "$1" >&2
  notify "android-mount" "$1" || true
  exit "${2:-1}"
}

notify() {
  if command -v notify-send > /dev/null 2>&1; then
    notify-send -a "Android Mount" "$@" > /dev/null 2>&1 || true
  fi
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

usage() {
  cat << 'EOF'
android-mount — mount Android devices over MTP

Usage:
  android-mount.sh [list] [--json] [--dry-run]
  android-mount.sh mount <device-index> [--dry-run]
  android-mount.sh unmount <device-index|path> [--dry-run]
  android-mount.sh --rofi            # interactive menu
  android-mount.sh status [--json]

Devices are mounted at ~/Android_Mount/<sanitised-name>-<index>.
Unmount with fusermount; the directory is removed only if it is empty.
Requires simple-mtpfs (and rofi/notify-send for the menu).
Nothing here uses sudo or writes outside your home directory.
EOF
}

require_tools() {
  local missing=()
  command -v simple-mtpfs > /dev/null 2>&1 || missing+=(simple-mtpfs)
  command -v fusermount > /dev/null 2>&1 ||
    command -v fusermount3 > /dev/null 2>&1 ||
    missing+=(fuse)
  if ((${#missing[@]})); then
    die "missing ${missing[*]} (pacman -S simple-mtpfs fuse2)"
  fi
}

list_devices() {
  require_tools
  simple-mtpfs -l 2> /dev/null | sed -n 's/^\([0-9][0-9]*\):[[:space:]]*/\1\t/p' || true
}

sanitize_name() {
  local name=$1
  name=${name//[^A-Za-z0-9._-]/_}
  name=${name##_}
  name=${name%%_}
  [[ -n $name ]] || name=android
  printf '%s' "${name:0:40}"
}

mount_point_for() {
  local index=$1 name=$2
  printf '%s/%s-%s' "$MOUNT_ROOT" "$(sanitize_name "$name")" "$index"
}

is_mounted() {
  local path=$1
  mountpoint -q -- "$path" 2> /dev/null
}

# Persisted so unmount works even if the device label changes after replug.
remember_mount() {
  local index=$1 path=$2 name=$3
  mkdir -p -- "$STATE_DIR"
  chmod 700 -- "$STATE_DIR"
  grep -v -E "^${index}	" "$STATE_FILE" 2> /dev/null > "$STATE_FILE.tmp" || true
  printf '%s\t%s\t%s\n' "$index" "$path" "$name" >> "$STATE_FILE.tmp"
  mv -f -- "$STATE_FILE.tmp" "$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

forget_mount() {
  local index=$1
  [[ -r $STATE_FILE ]] || return 0
  grep -v -E "^${index}	" "$STATE_FILE" > "$STATE_FILE.tmp" || true
  mv -f -- "$STATE_FILE.tmp" "$STATE_FILE"
}

known_mount() {
  local index=$1
  [[ -r $STATE_FILE ]] || return 1
  awk -F'\t' -v i="$index" '$1 == i { print $2; found=1 } END { exit !found }' "$STATE_FILE"
}

device_name() {
  local index=$1
  local name
  name=$(list_devices | awk -F'\t' -v i="$index" '$1 == i { print $2; found=1 } END { exit !found }') ||
    die "device $index not found; is it connected and unlocked?"
  printf '%s' "$name"
}

do_mount() {
  local index=$1
  [[ $index =~ ^[0-9]+$ ]] || die "device index must be a number" 2
  local name path
  name=$(device_name "$index")
  path=$(mount_point_for "$index" "$name")

  if is_mounted "$path"; then
    notify "already mounted" "$name → $path"
    [[ $DRY_RUN == 1 ]] || printf '%s\n' "$path"
    return 0
  fi

  # Never follow a symlink or mount over something unexpected.
  if [[ -L $path ]]; then
    die "refusing to mount over a symlink: $path"
  fi
  if [[ -e $path && ! -d $path ]]; then
    die "mount point is not a directory: $path"
  fi

  if [[ $DRY_RUN == 1 ]]; then
    printf '[dry-run] mkdir -p %q\n' "$path"
    printf '[dry-run] simple-mtpfs --device %s %q\n' "$index" "$path"
    return 0
  fi

  mkdir -p -- "$path"
  if ! simple-mtpfs --device "$index" "$path"; then
    rmdir -- "$path" 2> /dev/null || true
    die "mount failed for $name"
  fi
  remember_mount "$index" "$path" "$name"
  notify "mounted" "$name → $path"
  printf '%s\n' "$path"
}

do_unmount() {
  local target=$1 path
  if [[ $target =~ ^[0-9]+$ ]]; then
    path=$(known_mount "$target" || true)
    if [[ -z $path ]]; then
      path=$(list_devices | awk -F'\t' -v i="$target" '$1 == i { print $2 }' | head -n1)
      [[ -n $path ]] || die "device $target is not mounted" 1
      path=$(mount_point_for "$target" "$path")
    fi
  else
    path=$target
  fi

  # Containment check: only ever unmount inside our own root.
  local real_root real_path
  real_root=$(readlink -f -- "$MOUNT_ROOT" 2> /dev/null || printf '%s' "$MOUNT_ROOT")
  real_path=$(readlink -f -- "$path" 2> /dev/null || printf '%s' "$path")
  case $real_path in
    "$real_root"/*) ;;
    *) die "refusing to unmount outside $MOUNT_ROOT: $path" 2 ;;
  esac

  if ! is_mounted "$real_path"; then
    die "not a mount point: $real_path" 1
  fi

  if [[ $DRY_RUN == 1 ]]; then
    printf '[dry-run] fusermount -u %q && rmdir --ignore-fail-on-non-empty %q\n' "$real_path" "$real_path"
    return 0
  fi

  if command -v fusermount > /dev/null 2>&1; then
    fusermount -u -- "$real_path" || die "unmount failed (device busy?)"
  else
    fusermount3 -u -- "$real_path" || die "unmount failed (device busy?)"
  fi

  rmdir --ignore-fail-on-non-empty -- "$real_path" 2> /dev/null || true
  local idx
  idx=$(awk -F'\t' -v p="$real_path" '$2 == p { print $1 }' "$STATE_FILE" 2> /dev/null | head -n1)
  [[ -n $idx ]] && forget_mount "$idx"
  notify "unmounted" "$real_path"
  printf '%s\n' "$real_path"
}

print_status() {
  local index name path mounted
  if ((JSON)); then
    printf '{"mount_root":%s,"devices":[' "$(printf '"%s"' "$(json_escape "$MOUNT_ROOT")")"
    local sep=''
    while IFS=$'\t' read -r index name; do
      [[ -n $index ]] || continue
      path=$(mount_point_for "$index" "$name")
      mounted=false
      is_mounted "$path" && mounted=true
      printf '%s{"index":%s,"name":%s,"mountpoint":%s,"mounted":%s}' "$sep" \
        "$index" "\"$(json_escape "$name")\"" "\"$(json_escape "$path")\"" "$mounted"
      sep=','
    done < <(list_devices)
    printf ']}\n'
    return 0
  fi

  if ! list_devices | grep -q .; then
    printf 'No MTP devices found.\n'
    printf 'Unlock the phone, then set USB mode to "File transfer (MTP)".\n'
    return 1
  fi

  while IFS=$'\t' read -r index name; do
    [[ -n $index ]] || continue
    path=$(mount_point_for "$index" "$name")
    if is_mounted "$path"; then
      printf '%s\t%s\t[mounted] %s\n' "$index" "$name" "$path"
    else
      printf '%s\t%s\t[not mounted]\n' "$index" "$name"
    fi
  done < <(list_devices)
}

rofi_menu() {
  command -v rofi > /dev/null 2>&1 || die "rofi is required for the menu"
  local entries choice index path
  entries=$(print_status 2> /dev/null || true)
  if [[ -z $entries ]]; then
    notify "android-mount" "no MTP device found — unlock the phone and choose File transfer"
    return 1
  fi
  choice=$(printf '%s\n' "$entries" |
    rofi -dmenu -p android -theme "$HOME/.config/archway/theme.d/rofi.rasi") || return 1
  [[ -n $choice ]] || return 1
  index=$(printf '%s' "$choice" | cut -f1)
  path=$(printf '%s' "$choice" | awk -F'\t' '{print $3}')
  if [[ $path == \[mounted\]* ]]; then
    do_unmount "$index"
  else
    do_mount "$index"
  fi
}

main() {
  local -a positional=()
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      --json) JSON=1 ;;
      --rofi) ROFI=1 ;;
      list | mount | unmount | status) MODE=$1 ;;
      -*) die "unknown option: $1 (see --help)" 2 ;;
      *) positional+=("$1") ;;
    esac
    shift
  done
  ARG=${positional[0]:-}

  ((EUID == 0)) && die "must not run as root" 2

  if ((ROFI)); then
    rofi_menu
    return
  fi

  case $MODE in
    list) print_status ;;
    status) print_status ;;
    mount) do_mount "$ARG" ;;
    unmount) do_unmount "$ARG" ;;
    *) die "unknown mode: $MODE" 2 ;;
  esac
}

main "$@"
