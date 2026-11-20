#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# theme-selector — rofi modi that lists Archway themes and applies one.
#
# rofi calls this script with no arguments to get the list, and with the chosen
# entry as $1 to act on it. Rows are "id<TAB>Display Name" so the menu reads
# nicely while the id stays exact.
set -Eeuo pipefail

ARCHWAY_ROOT=${ARCHWAY_ROOT:-$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../.." && pwd)}
ARCHWAY="$ARCHWAY_ROOT/bin/archway"

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat << 'EOF'
theme-selector — Archway theme picker for rofi

Usage:
  theme-selector.sh              # list themes (rofi modi protocol)
  theme-selector.sh <row>        # apply the theme in the selected row
EOF
  exit 0
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
