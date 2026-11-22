#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# emoji — pick an emoji with the keyboard and put it on the clipboard.
#
# Every referential dotfiles setup has this and no two do it the same way: a
# rofi-emoji plugin (AUR, extra dependency), a giant JSON parsed at startup, or a
# wl-clipboard hack. This one ships a curated table (applets/emoji/emoji.tsv),
# reads it in one pass and copies the glyph with wl-copy. No plugin, no daemon,
# no network.
#
# Why a curated table and not the Unicode full list: the menu is a memory aid.
# 150 entries are readable at a glance and searchable by the words you actually
# think of ("fire", "check", "lock"), while 3.000 entries turn every search into
# scrolling. The file is data: extend it, keep one entry per line.
set -Eeuo pipefail

DRY_RUN=0
ACTION='list'
GLYPH=''
ROFI=0

SELF_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
DATA_FILE=${EMOJI_DATA:-$SELF_DIR/emoji.tsv}
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archway"
RECENT_FILE="$STATE_DIR/emoji-recent"
RECENT_MAX=12
ROFI_THEME=${ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/archway/theme.d/rofi.rasi}

usage() {
  cat << 'EOF'
emoji — emoji picker (rofi + wl-clipboard)

Usage:
  emoji.sh [list]                 # one "glyph<TAB>label" per entry
  emoji.sh --rofi                 # pick and copy (bound to Super+period)
  emoji.sh --copy <glyph>         # copy a glyph, no menu
  emoji.sh --json                 # {"entries":N,"recent":N}
  emoji.sh --dry-run --rofi       # print the menu rows, copy nothing

Entries come from applets/emoji/emoji.tsv; set EMOJI_DATA to use another table.
Recent picks are kept in ~/.local/state/archway/emoji-recent and listed first.
EOF
}

die() {
  printf 'emoji: %s\n' "$1" >&2
  notify "$1" || true
  exit "${2:-1}"
}

notify() {
  command -v notify-send > /dev/null 2>&1 && notify-send -a Archway "emoji" "$1" > /dev/null 2>&1 || true
}

have() { command -v "$1" > /dev/null 2>&1; }

# Data lines only: comments and blanks are not entries.
entries() {
  [[ -r $DATA_FILE ]] || die "table not found: $DATA_FILE" 3
  awk -F'\t' 'NF >= 2 && $1 !~ /^#/ && $1 != ""' "$DATA_FILE"
}

glyph_of() { printf '%s' "${1%%$'\t'*}"; }

recent_list() {
  [[ -r $RECENT_FILE ]] || return 0
  awk 'NF && !seen[$0]++' "$RECENT_FILE" | head -n "$RECENT_MAX"
}

recent_add() {
  local glyph=$1 tmp
  ((DRY_RUN)) && return 0
  tmp=$(mktemp) || return 0
  {
    printf '%s\n' "$glyph"
    recent_list | grep -vxF -- "$glyph" || true
  } |
    head -n "$RECENT_MAX" > "$tmp"
  mkdir -p -- "$STATE_DIR"
  mv -- "$tmp" "$RECENT_FILE"
}

copy_glyph() {
  local glyph=$1
  [[ -n $glyph ]] || die "copy: empty glyph" 2
  if ((DRY_RUN)); then
    printf '[dry-run] wl-copy %s\n' "$glyph"
    return 0
  fi
  have wl-copy || die "wl-copy not found (pacman -S wl-clipboard)" 3
  # --type text/plain is what applications pasting into a text field expect;
  # without it some toolkits offer the glyph as a file instead of text.
  printf '%s' "$glyph" | wl-copy --type text/plain || die "could not write to the clipboard" 1
  recent_add "$glyph"
  notify "copied $glyph"
}

# Menu rows: "<glyph> <name> — <keywords>", recents first with a star, then the
# table in file order. One space between fields on purpose: rofi 2.x treats a run
# of spaces as a column separator (see AGENTS.md, "Menús Rofi").
menu_labels() {
  local recent glyph label
  recent=$(recent_list)
  while IFS= read -r glyph; do
    [[ -n $glyph ]] || continue
    label=$(entries | awk -F'\t' -v g="$glyph" '$1 == g { print $2; exit }')
    [[ -n $label ]] || continue
    printf '★%s %s\n' "$glyph" "$label"
  done <<< "$recent"
  local skip
  skip=$(printf '%s\n' "$recent" | sed '/^$/d')
  entries | while IFS=$'\t' read -r g label; do
    grep -qxF -- "$g" <<< "$skip" && continue
    printf '%s %s\n' "$g" "$label"
  done
}

run_menu() {
  have rofi || die "rofi is required for the picker" 3
  local labels idx glyph
  labels=$(menu_labels)
  [[ -n $labels ]] || die "no entries in $DATA_FILE" 3

  if ((DRY_RUN)); then
    printf '%s\n' "$labels"
    return 0
  fi

  # -format i returns the row index; the glyph is the first field of that row, so
  # nothing has to be parsed out of the visible text.
  idx=$(printf '%s\n' "$labels" | rofi -dmenu -i -p emoji -format i -theme "$ROFI_THEME") || return 0
  [[ -n $idx ]] || return 0
  glyph=$(printf '%s\n' "$labels" | sed -n "$((idx + 1))p" | awk '{print $1}')
  glyph=${glyph#★}
  copy_glyph "$glyph"
}

status_json() {
  local count recent
  count=$(entries | wc -l)
  recent=$(recent_list | wc -l)
  printf '{"entries":%d,"recent":%d}\n' "$count" "$recent"
}

while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json) ACTION=json ;;
    --rofi) ROFI=1 ;;
    --copy)
      ACTION=copy
      GLYPH=${2:-}
      [[ -n $GLYPH ]] || die "--copy needs a glyph" 2
      shift
      ;;
    list) ACTION=list ;;
    *)
      die "unknown option: $1" 2
      ;;
  esac
  shift
done

case $ACTION in
  json) status_json ;;
  copy) copy_glyph "$GLYPH" ;;
  list)
    if ((ROFI)); then run_menu; else entries; fi
    ;;
esac
