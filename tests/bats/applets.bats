#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  # shellcheck source=../helpers/common.bash
  source "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_sandbox
  OSD="$ARCHWAY_ROOT/applets/osd/osd.sh"
  WALL="$ARCHWAY_ROOT/applets/wallpaper/wallpaper.sh"
  NET="$ARCHWAY_ROOT/applets/network/network.sh"
  CLIP="$ARCHWAY_ROOT/applets/clipboard/clipboard.sh"
  BAR="$ARCHWAY_ROOT/applets/bar/bar.sh"
}

teardown() {
  teardown_sandbox
}

@test "osd uses swayosd when it is installed" {
  mock_cmd swayosd-client 'printf "%s\n" "$*" >> "$HOME/osd.log"'
  run "$OSD" volume up
  assert_eq 0 "$status"
  assert_file_contains "$HOME/osd.log" "--output-volume raise"
}

@test "osd rejects an unknown volume action" {
  run "$OSD" volume louder
  assert_eq 2 "$status"
}

@test "osd dry-run prints the command instead of touching the mixer" {
  mock_cmd swayosd-client 'printf "%s\n" "$*" >> "$HOME/osd.log"'
  run "$OSD" --dry-run brightness down
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] swayosd-client --brightness lower"
  assert_missing "$HOME/osd.log"
}

@test "wallpaper lists images from the Archway data dir and ignores other files" {
  mkdir -p "$XDG_DATA_HOME/archway/wallpapers"
  printf 'x' > "$XDG_DATA_HOME/archway/wallpapers/a.png"
  printf 'x' > "$XDG_DATA_HOME/archway/wallpapers/notes.txt"
  run "$WALL" --json
  assert_eq 0 "$status"
  assert_contains "$output" "a.png"
  [[ $output != *notes.txt* ]] || fail "non-image file listed"
}

@test "wallpaper refuses a symlink and an unsupported extension" {
  mkdir -p "$XDG_DATA_HOME/archway/wallpapers"
  printf 'x' > "$SANDBOX/real.png"
  ln -s "$SANDBOX/real.png" "$XDG_DATA_HOME/archway/wallpapers/link.png"
  run "$WALL" --set "$XDG_DATA_HOME/archway/wallpapers/link.png"
  assert_eq 1 "$status"
  assert_contains "$output" "symlink"

  printf 'x' > "$SANDBOX/doc.pdf"
  run "$WALL" --set "$SANDBOX/doc.pdf"
  assert_eq 1 "$status"
  assert_contains "$output" "unsupported"
}

@test "wallpaper applies through hyprpaper and remembers the choice" {
  mkdir -p "$XDG_DATA_HOME/archway/wallpapers"
  printf 'x' > "$XDG_DATA_HOME/archway/wallpapers/a.png"
  mock_cmd pgrep 'exit 0'
  # A real hyprpaper must never start from a test: it inherits the test's stdout
  # and keeps the runner waiting for EOF.
  mock_cmd hyprpaper 'sleep 300'
  # hyprpaper 0.8: `wallpaper ,<path>` applies and `listactive` confirms it.
  # `preload`/`unload` are gone, so the applet must not call them any more.
  mock_cmd hyprctl 'printf "%s\n" "$*" >> "$HOME/hyprctl.log"
    if [[ $2 == wallpaper ]]; then
      printf "%s" "${3#*,}" > "$HOME/active"
    elif [[ $2 == listactive ]]; then
      printf "LVDS-1: %s\n" "$(cat "$HOME/active")"
    fi'
  run "$WALL" --set "$XDG_DATA_HOME/archway/wallpapers/a.png"
  assert_eq 0 "$status"
  assert_file_contains "$HOME/hyprctl.log" "hyprpaper wallpaper ,$XDG_DATA_HOME/archway/wallpapers/a.png"
  assert_file_contains "$HOME/hyprctl.log" "hyprpaper listactive"
  assert_file_contains "$XDG_STATE_HOME/archway/wallpaper" "a.png"
  assert_file_contains "$HOME/.config/hypr/hyprpaper.conf" "path = $XDG_DATA_HOME/archway/wallpapers/a.png"
}

@test "network dry-run does not change the radio" {
  mock_cmd nmcli 'printf "%s\n" "$*" >> "$HOME/nmcli.log"'
  run "$NET" --dry-run --wifi off
  assert_eq 0 "$status"
  assert_contains "$output" "nmcli radio wifi off"
  assert_missing "$HOME/nmcli.log"
}

@test "network menu lists networks with signal and lock state" {
  mock_cmd nmcli 'case "$*" in
    "radio wifi") printf "enabled\n" ;;
    *"device wifi list"*) printf "IN-USE:*\nSSID:HomeNet\nSIGNAL:82\nSECURITY:WPA2\nIN-USE:\nSSID:Cafe\nSIGNAL:44\nSECURITY:--\n" ;;
    *) printf "\n" ;;
  esac'
  mock_cmd rofi 'cat > "$HOME/rofi-input.log"; printf ""'
  run "$NET" --rofi
  assert_eq 0 "$status"
  assert_file_contains "$HOME/rofi-input.log" "HomeNet"
  assert_file_contains "$HOME/rofi-input.log" "Cafe"
  assert_file_contains "$HOME/rofi-input.log" "(connected)"
}

@test "clipboard reports an empty history and starts the watcher" {
  mock_cmd cliphist 'if [[ $1 == list ]]; then exit 0; fi'
  mock_cmd wl-paste 'sleep 5'
  mock_cmd wl-copy 'exit 0'
  run "$CLIP" --list --json
  assert_eq 0 "$status"
  assert_contains "$output" '"entries":0'
}

@test "bar updates stays visible but muted when the system is current" {
  # Regression: hiding the pill at zero made the button look broken, so the
  # module now reports a muted check mark instead of an empty text.
  mock_cmd checkupdates 'exit 2'
  run "$BAR" updates
  assert_eq 0 "$status"
  assert_contains "$output" '"class": "muted"'
  assert_contains "$output" "up to date"
}

@test "bar updates reports the pending count" {
  mock_cmd checkupdates 'printf "a 1 -> 2\nb 1 -> 2\n"'
  run "$BAR" updates
  assert_eq 0 "$status"
  assert_contains "$output" '"class": "warning"'
  run grep -q '"text": ""' <<< "$output"
  assert_eq 1 "$status"
}

@test "bar failed counts failed units and escalates to critical" {
  mock_cmd systemctl 'printf "a.service loaded failed failed A\nb.service loaded failed failed B\n"'
  run "$BAR" failed
  assert_eq 0 "$status"
  assert_contains "$output" '"class": "critical"'
  assert_contains "$output" "2"
}

@test "bar failed is hidden when nothing failed" {
  mock_cmd systemctl 'exit 0'
  run "$BAR" failed
  assert_contains "$output" '"text": ""'
}

@test "bar vault stays hidden when rbw is not configured" {
  run "$BAR" vault
  assert_eq 0 "$status"
  assert_contains "$output" '"text": ""'
}

@test "bar power-profile cycles performance to balanced" {
  mock_cmd powerprofilesctl 'case $1 in get) echo performance ;; set) printf "%s\n" "$2" > "$HOME/pp" ;; esac'
  run "$BAR" power-profile --next
  assert_eq 0 "$status"
  assert_eq balanced "$(cat "$HOME/pp")"
}

@test "bar rejects an unknown section with the usage exit code" {
  run "$BAR" nope
  assert_eq 2 "$status"
}

@test "bar help documents every section" {
  run "$BAR" --help
  assert_eq 0 "$status"
  assert_contains "$output" "power-profile"
  assert_contains "$output" "scratchpad"
}

# --- terminal: open on the side of the workspace the cursor is on -------------

# Fake compositor: one 1366x768 monitor with a 32 px bar reserved at the top, so
# the work area is 0,32 1366x736 and its centre is 683,400.
mock_hypr_for_terminal() {
  printf '%s\n' \
    '[{"x":0,"y":0,"width":1366,"height":768,"reserved":[0,32,0,0],"focused":true}]' \
    > "$HOME/monitors.json"
  mock_cmd hyprctl 'case "$*" in
    "monitors -j") cat "$HOME/monitors.json" ;;
    "cursorpos") printf "%s, %s\n" "$T_CX" "$T_CY" ;;
    *) printf "[]\n" ;;
  esac'
}

@test "terminal picks the side of the cursor over the workspace area" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  mock_hypr_for_terminal
  # A real terminal must never be started by a report: --json is read-only.
  mock_cmd kitty 'printf "spawned\n" >> "$HOME/spawned"'
  export T_CX=683 T_CY=730
  run "$TERM_APP" --json
  assert_eq 0 "$status"
  assert_contains "$output" '"direction": "down"'

  export T_CX=683 T_CY=90
  run "$TERM_APP" --json
  assert_contains "$output" '"direction": "up"'

  export T_CX=1300 T_CY=420
  run "$TERM_APP" --json
  assert_contains "$output" '"direction": "right"'

  export T_CX=40 T_CY=420
  run "$TERM_APP" --json
  assert_contains "$output" '"direction": "left"'
  assert_missing "$HOME/spawned"
}

@test "terminal leaves the pointer in the middle band to dwindle" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  mock_hypr_for_terminal
  export T_CX=690 T_CY=405
  run "$TERM_APP" --dry-run
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] centre:"
}

@test "terminal dry-run reports the decision without starting anything" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  mock_hypr_for_terminal
  mock_cmd kitty 'printf "spawned\n" >> "$HOME/spawned"'
  export T_CX=683 T_CY=730
  run "$TERM_APP" --dry-run
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] down:"
  assert_contains "$output" "[dry-run] kitty &"
  assert_missing "$HOME/spawned"
}

@test "terminal fails clearly without a Hyprland session" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  mock_cmd hyprctl 'printf "Could not connect to socket\n" >&2; exit 1'
  run "$TERM_APP"
  assert_eq 3 "$status"
  assert_contains "$output" "monitor geometry"
}

@test "terminal rejects an unknown option with the usage exit code" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  run "$TERM_APP" --nope
  assert_eq 2 "$status"
}

# --------------------------------------------------------------- window -----

_window_mock() {
  cat > "$HOME/clients.json" << JSON
[{"address":"0xabc","class":"kitty","fullscreen":${1:-0},"floating":false,"focusHistoryID":0}]
JSON
  mock_cmd hyprctl 'case "$1" in
    clients) cat "$HOME/clients.json" ;;
    dispatch) printf "%s\n" "$2" >> "$HOME/dispatch.log" ;;
  esac'
}

@test "window maximize asks for the maximized mode, not fullscreen" {
  WIN="$ARCHWAY_ROOT/applets/window/window.sh"
  _window_mock 0
  run "$WIN" maximize
  assert_eq 0 "$status"
  assert_file_contains "$HOME/dispatch.log" 'fullscreen({ mode = "maximized" })'
}

@test "window status reports a maximized window" {
  WIN="$ARCHWAY_ROOT/applets/window/window.sh"
  _window_mock 1
  run "$WIN" --status
  assert_eq 0 "$status"
  assert_contains "$output" "maximized"
}

@test "window center refuses a tiled window" {
  WIN="$ARCHWAY_ROOT/applets/window/window.sh"
  _window_mock 0
  run "$WIN" center
  assert_eq 1 "$status"
  assert_contains "$output" "float it first"
}

# --------------------------------------------------------------- gaming -----

@test "gaming mode sets performance and restores the saved profile" {
  GAME="$ARCHWAY_ROOT/applets/gaming/gaming.sh"
  mock_cmd powerprofilesctl 'case "$1" in
    get) cat "$HOME/profile" 2>/dev/null || echo balanced ;;
    set) printf "%s\n" "$2" > "$HOME/profile" ;;
  esac'
  mock_cmd swaync-client 'case "$1" in
    -D) echo false ;;
    *) printf "%s\n" "$1" >> "$HOME/dnd.log" ;;
  esac'

  run "$GAME" on
  assert_eq 0 "$status"
  assert_file_contains "$HOME/profile" "performance"
  run "$GAME" status --json
  assert_contains "$output" '"enabled":true'

  run "$GAME" off
  assert_eq 0 "$status"
  assert_file_contains "$HOME/profile" "balanced"
  run "$GAME" status --json
  assert_contains "$output" '"enabled":false'
}

@test "gaming toggle is idempotent about its state file" {
  GAME="$ARCHWAY_ROOT/applets/gaming/gaming.sh"
  mock_cmd powerprofilesctl 'printf "%s\n" "$2" > "$HOME/profile"'
  run "$GAME" --dry-run on
  assert_eq 0 "$status"
  assert_missing "$XDG_STATE_HOME/archway/gaming.state"
}

# ------------------------------------------------------------- terminal -----

@test "terminal --print falls back to kitty" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  run "$TERM_APP" --print
  assert_eq 0 "$status"
  assert_contains "$output" "kitty"
}

@test "terminal --set stores the choice and --print reads it back" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  mock_cmd alacritty 'exit 0'
  run "$TERM_APP" --set alacritty
  assert_eq 0 "$status"
  run "$TERM_APP" --print
  assert_contains "$output" "alacritty"
}

@test "terminal --set refuses a program that is not installed" {
  TERM_APP="$ARCHWAY_ROOT/applets/terminal/terminal.sh"
  run "$TERM_APP" --set ghostty-nonexistent
  assert_eq 3 "$status"
  assert_contains "$output" "is not installed"
}

# ------------------------------------------------------------ wallpaper -----

@test "wallpaper dry-run prints the hyprpaper request it would send" {
  img="$XDG_DATA_HOME/archway/wallpapers/a.png"
  mkdir -p -- "$(dirname -- "$img")"
  printf 'not really a png\n' > "$img"
  run "$WALL" --dry-run --set "$img"
  assert_eq 0 "$status"
  assert_contains "$output" 'hyprctl hyprpaper wallpaper'
}
