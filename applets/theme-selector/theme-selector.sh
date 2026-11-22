#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# theme-selector — theme picker for rofi.
#
# Two entry points, same data:
#   theme-selector.sh --rofi        own the whole menu (what Super+Space calls)
#   theme-selector.sh [row]         rofi modi protocol: list, then apply $1
#
# --rofi exists because `rofi -show theme -modi "theme:$HOME/... applet"` puts a
# quoted shell command inside a TOML value inside a Lua string, and one layer of
# escaping goes wrong: rofi got `-modi \"theme:...` and answered "mode theme not
# found". A picker that opens its own menu has no nested quoting to get wrong.
#
# Rows are "id<TAB>Display Name" so the menu reads nicely while the id stays
# exact; both paths take the id from the first field.
set -Eeuo pipefail

ARCHWAY_ROOT=${ARCHWAY_ROOT:-$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../.." && pwd)}
ARCHWAY=${ARCHWAY:-$ARCHWAY_ROOT/bin/archway}
ROFI_THEME=${ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/archway/theme.d/rofi.rasi}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat << 'EOF'
theme-selector — Archway theme picker for rofi

Usage:
  theme-selector.sh --rofi       # open the picker (Super+Space)
  theme-selector.sh --dry-run --rofi  # print the rows, open nothing
  theme-selector.sh              # list themes (rofi modi protocol)
  theme-selector.sh <row>        # apply the theme in the selected row
EOF
  exit 0
fi

DRY_RUN=0
if [[ ${1:-} == --dry-run ]]; then
  DRY_RUN=1
  shift
fi

if [[ ${1:-} == --rofi ]]; then
  rows=$("$ARCHWAY" theme list --names)
  [[ -n $rows ]] || {
    printf 'theme-selector: no themes found\n' >&2
    exit 1
  }
  # The menu shows only the display name: a tab between id and name is drawn as a
  # column separator and leaves a gap the eye reads as missing text. The index
  # still points into `rows`, so the id stays exact.
  labels=$(printf '%s\n' "$rows" | cut -f2-)

  if ((DRY_RUN)); then
    printf '%s\n' "$labels"
    exit 0
  fi
  command -v rofi > /dev/null 2>&1 || {
    printf 'theme-selector: rofi is required for the picker\n' >&2
    exit 3
  }
  idx=$(printf '%s\n' "$labels" | rofi -dmenu -i -p theme -format i -theme "$ROFI_THEME") || exit 0
  [[ -n $idx ]] || exit 0
  row=$(printf '%s\n' "$rows" | sed -n "$((idx + 1))p")
  id=${row%%[[:space:]]*}
  exec "$ARCHWAY" theme set "$id"
fi

if [[ -z ${1:-} ]]; then
  "$ARCHWAY" theme list --names
  exit 0
fi

# rofi may hand back the row with a tab or with spaces; the id is the first
# field either way. A leading '* ' marks the current theme in `theme list`.
id=${1%%[[:space:]]*}
id=${id#\*}
exec "$ARCHWAY" theme set "$id"
