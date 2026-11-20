#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# wallpaper — pick, apply and restore a wallpaper on Hyprland.
#
# Wallpapers are user data, so Archway never ships or deletes any. It reads the
# folders below, keeps the last choice in ~/.local/state/archway/wallpaper and
# restores it at session start. hyprpaper does the drawing.
set -Eeuo pipefail

DRY_RUN=0
JSON=0
ROFI=0
MODE='list'

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/archway/wallpapers"
PICTURES_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway"
STATE_FILE="$STATE_DIR/wallpaper"

usage() {
  cat << 'EOF'
wallpaper — Wayland wallpaper picker (hyprpaper)

Usage:
  wallpaper.sh [list] [--json]
  wallpaper.sh --rofi             # pick from a list (bound to Super+Alt+W)
  wallpaper.sh --set <file>
  wallpaper.sh --restore          # apply the last choice (session start)

Directories: ~/.local/share/archway/wallpapers and ~/Pictures/Wallpapers.
Supported: jpg, jpeg, png, webp. hyprpaper must be running (Archway starts it).
EOF
}

die() {
  printf 'wallpaper: %s\n' "$1" >&2
  notify "wallpaper" "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "$@" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

is_image() {
  local file=${1,,}
  case $file in
    *.jpg | *.jpeg | *.png | *.webp) return 0 ;;
    *) return 1 ;;
  esac
}

# One path per line, de-duplicated, stable order. Symlinks are skipped so a
# dangling link cannot make the picker offer an unusable entry.
wp_list() {
  local dir
  for dir in "$DATA_DIR" "$PICTURES_DIR"; do
    [[ -d $dir ]] || continue
    find "$dir" -maxdepth 2 -type f ! -type l 2> /dev/null | while IFS= read -r f; do
      is_image "$f" && printf '%s\n' "$f"
    done
  done | sort -u
}

wp_running() { pgrep -x hyprpaper > /dev/null 2>&1; }

wp_show() {
  local path=$1
  [[ -f $path ]] || die "not a file: $path"
  [[ -L $path ]] && die "refusing to follow a symlink: $path"
  is_image "$path" || die "unsupported image type: $path"

  if ((DRY_RUN)); then
    printf '[dry-run] hyprctl hyprpaper preload %s\n' "$path"
    printf '[dry-run] hyprctl hyprpaper wallpaper ,%s\n' "$path"
    return 0
  fi

  have hyprctl || die "hyprctl not found (is Hyprland running?)" 3
  if ! wp_running; then
    have hyprpaper || die "hyprpaper is not installed (pacman -S hyprpaper)" 3
    setsid hyprpaper > /dev/null 2>&1 &
    sleep 1
  fi
  wp_running || die "hyprpaper is not running" 3

  hyprctl hyprpaper unload all > /dev/null 2>&1 || true
  hyprctl hyprpaper preload "$path" > /dev/null 2>&1 || die "hyprpaper could not preload $path"
  hyprctl hyprpaper wallpaper ",$path" > /dev/null 2>&1 || die "hyprpaper could not apply $path"

  mkdir -p -- "$STATE_DIR"
  printf '%s\n' "$path" > "$STATE_FILE"
  chmod 644 -- "$STATE_FILE"
  notify "wallpaper" "$(basename -- "$path")"
}

wp_restore() {
  [[ -r $STATE_FILE ]] || return 0
  local path
  path=$(head -n1 "$STATE_FILE")
  [[ -n $path && -f $path ]] || return 0
  wp_running || return 0
  hyprctl hyprpaper unload all > /dev/null 2>&1 || true
  hyprctl hyprpaper preload "$path" > /dev/null 2>&1 || return 0
  hyprctl hyprpaper wallpaper ",$path" > /dev/null 2>&1 || return 0
}

wp_json() {
  local path sep=''
  printf '['
  while IFS= read -r path; do
    printf '%s%s' "$sep" "$(json_quote "$path")"
    sep=','
  done < <(wp_list)
  printf ']\n'
}

json_quote() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

wp_rofi() {
  have rofi || die "rofi is required for the picker" 3
  local entries=''
  entries=$(wp_list)
  if [[ -z $entries ]]; then
    die "no wallpapers found — drop images in $DATA_DIR or $PICTURES_DIR"
  fi
  local rows choice path
  rows=$(
    while IFS= read -r path; do
      printf '%s\t%s\n' "$(basename -- "$path")" "$path"
    done <<< "$entries"
  )
  # -format s returns the whole selected row, so the path comes back intact
  # even when two files share a name in different folders.
  choice=$(printf '%s\n' "$rows" |
    rofi -dmenu -i -p wallpaper -display-columns 1 -format s \
      -theme "$HOME/.config/archway/theme.d/rofi.rasi") || return 1
  [[ -n $choice ]] || return 1
  path=${choice#*$'\t'}
  wp_show "$path"
}

main() {
  local set_path=''
  while (($#)); do
    case $1 in
      --help | -h)
        usage
        exit 0
        ;;
      --dry-run) DRY_RUN=1 ;;
      --json) JSON=1 ;;
      --rofi) ROFI=1 ;;
      --restore) MODE=restore ;;
      --set)
        MODE='set'
        set_path=${2:-}
        [[ -n $set_path ]] || die "--set needs a file path" 2
        shift
        ;;
      list) MODE=list ;;
      -*)
        usage >&2
        die "unknown option: $1" 2
        ;;
      *) die "unexpected argument: $1" 2 ;;
    esac
    shift
  done

  case $MODE in
    restore) wp_restore ;;
    set) wp_show "$set_path" ;;
    list)
      if ((JSON)); then
        wp_json
      elif ((ROFI)); then
        wp_rofi
      else
        local count=0 path
        while IFS= read -r path; do
          printf '%s\n' "$path"
          count=$((count + 1))
        done < <(wp_list)
        ((count)) || printf 'no wallpapers in %s or %s\n' "$DATA_DIR" "$PICTURES_DIR" >&2
      fi
      ;;
  esac
}

main "$@"
