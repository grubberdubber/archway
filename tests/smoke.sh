#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# End-to-end smoke suite. Runs without bats and never touches the real $HOME.
# Usage: tests/smoke.sh [check-name...]
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ARCHWAY="$ROOT/bin/archway"
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/archway-smoke.XXXXXX")
export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME"
unset NO_COLOR || true
export NO_COLOR=1

PASS=0
FAIL=0

cleanup() { rm -rf -- "$SANDBOX"; }
trap cleanup EXIT

pass() {
  PASS=$((PASS + 1))
  printf '  ok   %s\n' "$1"
}
nope() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n' "$1" >&2
  [[ -n ${2:-} ]] && printf '       %s\n' "$2" >&2
}

# expect_status <expected> <name> <command...>
expect_status() {
  local expected=$1 name=$2
  shift 2
  local out status=0
  out=$("$@" 2>&1) || status=$?
  if [[ $status == "$expected" ]]; then
    pass "$name"
  else
    nope "$name" "expected exit $expected, got $status; output: ${out:0:200}"
  fi
}

expect_output() {
  local needle=$1 name=$2
  shift 2
  local out
  if out=$("$@" 2>&1) && [[ $out == *"$needle"* ]]; then
    pass "$name"
  else
    nope "$name" "missing '$needle' in: ${out:0:200}"
  fi
}

run_selected() {
  local name=$1
  shift
  (($# == 0)) && return 0
  for want in "$@"; do [[ $want == "$name" ]] && return 0; done
  return 1
}

# ---------------------------------------------------------------- checks ----

check_version() {
  expect_status 0 "version --json parses" bash -c "$ARCHWAY version --json | jq -e .version"
  expect_output "archway" "version prints a name" "$ARCHWAY" version
}

check_theme() {
  expect_status 0 "theme validate" "$ARCHWAY" theme validate android-mount
  local dest="$SANDBOX/render"
  mkdir -p "$dest"
  expect_status 0 "theme render" "$ARCHWAY" theme render android-mount --to "$dest"
  if grep -rq '@[a-z_]*@' "$dest"; then
    nope "render leaves no tokens"
  else
    pass "render leaves no tokens"
  fi
  expect_status 0 "nvim theme contract" "$ARCHWAY" theme nvim-contract android-mount
  expect_status 0 "theme set (no nvim installed)" "$ARCHWAY" theme set android-mount
  if [[ -f $XDG_CONFIG_HOME/archway/theme.d/kitty.conf ]]; then
    pass "theme set writes theme.d"
  else
    nope "theme set writes theme.d"
  fi
  if [[ -f $XDG_CONFIG_HOME/archway/theme.toml ]]; then
    pass "theme set records state"
  else
    nope "theme set records state"
  fi
}

check_keys() {
  expect_status 0 "keys validate" "$ARCHWAY" keys validate
  expect_status 0 "keys artifacts in sync" "$ARCHWAY" keys check
  expect_output "super + Return" "keys list" "$ARCHWAY" keys list
}

check_doctor() {
  expect_status 0 "doctor json ok" bash -c "$ARCHWAY doctor --json | jq -e '.ok == true'"
}

check_backup() {
  local target="$HOME/.config/kitty/kitty.conf"
  mkdir -p "$(dirname "$target")"
  printf 'font_size 11\n' > "$target"
  expect_status 0 "backup create" "$ARCHWAY" backup create
  local id
  id=$(find "$XDG_STATE_HOME/archway/backups" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | head -1)
  [[ -n $id ]] || {
    nope "backup id discovered"
    return 0
  }
  printf 'clobbered\n' > "$target"
  expect_status 0 "restore" "$ARCHWAY" restore "$id" --yes
  if [[ $(cat "$target") == "font_size 11" ]]; then
    pass "restore returns original content"
  else
    nope "restore returns original content"
  fi
}

check_android_mount() {
  mkdir -p "$SANDBOX/bin"
  cat > "$SANDBOX/bin/simple-mtpfs" << 'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == -l ]]; then printf '1: Pixel 7\n'; exit 0; fi
exit 0
EOF
  cat > "$SANDBOX/bin/fusermount" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "$SANDBOX/bin/notify-send" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$SANDBOX/bin"/*
  local PATH="$SANDBOX/bin:$PATH"
  export PATH

  expect_output "Pixel 7" "android-mount lists devices" "$ARCHWAY" applet android-mount list
  expect_status 0 "android-mount json parses" bash -c \
    "$ARCHWAY applet android-mount list --json | jq -e '.devices[0].name == \"Pixel 7\"'"
  expect_status 0 "android-mount mount" "$ARCHWAY" applet android-mount mount 1
  if [[ -d $HOME/Android_Mount/Pixel_7-1 ]]; then
    pass "mount point created"
  else
    nope "mount point created"
  fi
  expect_status 2 "android-mount refuses to unmount outside its root" \
    "$ARCHWAY" applet android-mount unmount /tmp --dry-run
  expect_status 0 "android-mount mount dry-run writes nothing" \
    "$ARCHWAY" applet android-mount mount 1 --dry-run
}

check_install_plan() {
  cat > "$SANDBOX/bin/chezmoi" << 'EOF'
#!/usr/bin/env bash
# fake chezmoi: status lists one pending file, apply does nothing
for arg in "$@"; do
  case $arg in
    status) printf ' A .config\n A .config/kitty\n M .config/kitty/kitty.conf\n'; exit 0 ;;
    apply) exit 0 ;;
  esac
done
exit 0
EOF
  chmod +x "$SANDBOX/bin/chezmoi"
  export PATH="$SANDBOX/bin:$PATH"

  local out status=0
  out=$("$ARCHWAY" install --dry-run --profile developer 2>&1) || status=$?
  if [[ $status == 0 && $out == *"Archway install plan"* ]]; then
    pass "install --dry-run prints a plan"
  else
    nope "install --dry-run prints a plan" "exit $status: ${out:0:300}"
  fi
  if [[ -e $XDG_CONFIG_HOME/bspwm || -e $XDG_CONFIG_HOME/sxhkd ]]; then
    nope "install --dry-run writes nothing"
  else
    pass "install --dry-run writes nothing"
  fi
}

check_uninstall() {
  if [[ ! -x $SANDBOX/bin/chezmoi ]]; then
    cat > "$SANDBOX/bin/chezmoi" << 'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  case $arg in
    status) printf ' A .config\n A .config/kitty\n A .config/kitty/kitty.conf\n M .config/zsh/.zshrc\n'; exit 0 ;;
    apply) exit 0 ;;
  esac
done
exit 0
EOF
    chmod +x "$SANDBOX/bin/chezmoi"
  fi
  export PATH="$SANDBOX/bin:$PATH"

  mkdir -p "$HOME/.config/myapp"
  printf 'mine\n' > "$HOME/.config/myapp/keep.conf"

  expect_status 0 "install applies without packages or nvim" \
    "$ARCHWAY" install --profile developer --no-packages --no-nvim --yes

  local manifest="$XDG_STATE_HOME/archway/managed.tsv"
  if [[ -r $manifest ]] && ! cut -f1 "$manifest" | grep -qxF "$XDG_CONFIG_HOME"; then
    pass "manifest never records the XDG config root"
  else
    nope "manifest never records the XDG config root"
  fi

  expect_status 0 "uninstall --dry-run" "$ARCHWAY" uninstall --dry-run
  expect_status 0 "uninstall" "$ARCHWAY" uninstall --yes
  if [[ -f $HOME/.config/myapp/keep.conf ]]; then
    pass "uninstall preserves unmanaged files"
  else
    nope "uninstall preserves unmanaged files"
  fi
  if [[ -d $XDG_CONFIG_HOME ]]; then
    pass "uninstall keeps the XDG config root"
  else
    nope "uninstall keeps the XDG config root"
  fi
}

ALL_CHECKS=(version theme keys doctor backup android_mount install_plan uninstall)

main() {
  printf 'archway smoke tests (sandbox: %s)\n' "$SANDBOX"
  local name
  for name in "${ALL_CHECKS[@]}"; do
    run_selected "$name" "$@" || continue
    printf '\n[%s]\n' "$name"
    "check_$name"
  done
  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
  ((FAIL == 0))
}

main "$@"
