#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# theme-selector — rofi modi that lists Archway themes and applies one.
#
# rofi calls this script with no arguments to get the list, and with the chosen
# entry as $1 to act on it.
set -Eeuo pipefail

ARCHWAY_ROOT=${ARCHWAY_ROOT:-$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../.." && pwd)}
ARCHWAY="$ARCHWAY_ROOT/bin/archway"

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat << 'EOF'
theme-selector — Archway theme picker for rofi

Usage:
  theme-selector.sh              # list themes (rofi modi protocol)
  theme-selector.sh <theme-id>   # apply a theme
EOF
  exit 0
fi

if [[ -z ${1:-} ]]; then
  "$ARCHWAY" theme list | sed 's/^\* //'
  exit 0
fi

exec "$ARCHWAY" theme set "$1"
