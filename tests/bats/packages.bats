#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Package selection must never ask pacman to remove software the user has.

load ../helpers/common

setup() {
  setup_sandbox
  FAKEBIN="$SANDBOX/bin"
  mkdir -p -- "$FAKEBIN"
  cat > "$FAKEBIN/pacman" << 'FAKE'
#!/usr/bin/env bash
# Minimal pacman stand-in: INSTALLED and PROVIDED are space separated lists,
# CONFLICTS maps a candidate package to its Conflicts With entry.
installed_has() { [[ " ${INSTALLED:-} " == *" $1 "* ]]; }
provided_has() { [[ " ${PROVIDED:-} " == *" $1 "* ]]; }
first=$1
shift
args=()
for a in "$@"; do [[ $a == "--" ]] || args+=("$a"); done
case $first in
  -T)
    rc=0
    for n in "${args[@]}"; do
      installed_has "$n" || provided_has "$n" || { printf '%s\n' "$n"; rc=1; }
    done
    exit "$rc"
    ;;
  -Qq)
    rc=1
    for n in "${args[@]}"; do
      if installed_has "$n"; then printf '%s\n' "$n"; rc=0; fi
    done
    exit "$rc"
    ;;
  -Si)
    printf 'Repository      : extra\n'
    printf 'Name            : %s\n' "${args[0]}"
    for pair in ${CONFLICTS:-}; do
      [[ ${pair%%:*} == "${args[0]}" ]] && printf 'Conflicts With  : %s\n' "${pair#*:}"
    done
    exit 0
    ;;
  *) exit 0 ;;
esac
FAKE
  chmod +x -- "$FAKEBIN/pacman"
  export PATH="$FAKEBIN:$PATH"
}

@test "a package satisfied by a virtual provide is not reinstalled" {
  export INSTALLED="nodejs-lts-jod" PROVIDED="nodejs"
  run packages_unsatisfied nodejs kitty
  [ "$status" -eq 0 ]
  [[ $output == "kitty" ]]
}

@test "conflicts with installed packages are reported" {
  export INSTALLED="tldr" CONFLICTS="tealdeer:tldr"
  run packages_conflicts tealdeer zoxide
  [ "$status" -eq 0 ]
  [[ $output == "tealdeer tldr" ]]
}

@test "uninstalled packages are never reported as conflicting" {
  export INSTALLED="" CONFLICTS="tealdeer:tldr"
  run packages_conflicts tealdeer
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "packages_installable drops what cannot be installed safely" {
  export INSTALLED="tldr nodejs-lts-jod" PROVIDED="nodejs" CONFLICTS="tealdeer:tldr"
  local list
  list=$(packages_installable tealdeer nodejs kitty zoxide 2> /dev/null)
  [[ $list == "kitty"$'\n'"zoxide" ]]
}
