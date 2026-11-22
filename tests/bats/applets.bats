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
  # A real hyprpaper must never start from a test, and a mock that sleeps would
  # keep the runner's stdout open until it exits (that is how the first CI run
  # hung for five minutes after the last test printed "ok").
  mock_cmd hyprpaper 'exit 0'
  export HYPRLAND_INSTANCE_SIGNATURE=test-instance
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

@test "network menu trims nmcli's column padding" {
  mock_cmd nmcli 'case "$*" in
    "radio wifi") printf "enabled\n" ;;
    *"device wifi list"*) printf "IN-USE:                                 *\nSSID:                                   HomeNet\nSIGNAL:                                 82\nSECURITY:                               WPA2\n" ;;
    *) printf "\n" ;;
  esac'
  mock_cmd rofi 'cat > "$HOME/rofi-input.log"; printf ""'
  run "$NET" --rofi
  assert_eq 0 "$status"
  assert_file_contains "$HOME/rofi-input.log" "HomeNet 82%"
  # rofi 2.x turns a run of spaces into columns, so the row must not contain one.
  run grep -c '  ' "$HOME/rofi-input.log"
  assert_contains "$output" "0"
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

@test "emoji picker lists entries, copies a glyph and remembers it" {
  local E="$ARCHWAY_ROOT/applets/emoji/emoji.sh"
  export XDG_STATE_HOME="$HOME/state"
  mock_cmd wl-copy 'cat > "$HOME/copied.txt"'
  mock_cmd notify-send 'exit 0'

  run "$E" --json
  assert_eq 0 "$status"
  assert_contains "$output" '"entries":'

  run "$E" --copy "$(printf '🙂')"
  assert_eq 0 "$status"
  assert_file_contains "$HOME/copied.txt" "🙂"
  assert_file_contains "$XDG_STATE_HOME/archway/emoji-recent" "🙂"
}

@test "emoji menu rows use single spaces so rofi does not split columns" {
  local E="$ARCHWAY_ROOT/applets/emoji/emoji.sh"
  run "$E" --dry-run --rofi
  assert_eq 0 "$status"
  assert_contains "$output" "grinning"
  run grep -c '  ' <<< "$output"
  assert_contains "$output" "0"
}

@test "theme selector builds its own menu with display names only" {
  local T="$ARCHWAY_ROOT/applets/theme-selector/theme-selector.sh"
  run "$T" --dry-run --rofi
  assert_eq 0 "$status"
  assert_contains "$output" "Android Mount"
  # A tab would be drawn as a column separator and leave a gap in the menu.
  run grep -c $'\t' <<< "$output"
  assert_eq 0 "$output"
}

@test "theme selector modi path applies the theme named in the row" {
  local T="$ARCHWAY_ROOT/applets/theme-selector/theme-selector.sh"
  mock_cmd archway 'echo "archway $*" > "$HOME/called.txt"'
  run env ARCHWAY="$SANDBOX/bin/archway" "$T" "ember	Ember"
  assert_eq 0 "$status"
  assert_file_contains "$HOME/called.txt" "theme set ember"
}

@test "record starts, reports and stops the recorder with SIGINT" {
  local R="$ARCHWAY_ROOT/applets/record/record.sh"
  export XDG_STATE_HOME="$HOME/state"
  export XDG_VIDEOS_DIR="$HOME/videos"
  mock_cmd notify-send 'exit 0'
  # A fake recorder: creates the file, waits for SIGINT, then exits cleanly.
  mock_cmd wf-recorder 'out=""
    while (($#)); do [[ $1 == -f ]] && out=$2; shift; done
    : > "$out"
    trap ": > \"$out\"; exit 0" INT
    while :; do sleep 0.2; done'

  run "$R" start
  assert_eq 0 "$status"
  run "$R" status --json
  assert_contains "$output" '"recording":true'
  assert_contains "$output" "videos/Recordings/recording-"

  run "$R" stop
  assert_eq 0 "$status"
  run "$R" status --json
  assert_contains "$output" '"recording":false'
}

@test "record dry-run prints the command and needs nothing installed" {
  local R="$ARCHWAY_ROOT/applets/record/record.sh"
  export XDG_VIDEOS_DIR="$HOME/videos"
  run "$R" --dry-run start --region --audio
  assert_eq 0 "$status"
  assert_contains "$output" "wf-recorder -f"
  assert_contains "$output" "--audio"
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

@test "bar update list survives a busy checkupdates" {
  # The click handler used to run a second `checkupdates`, which fails with
  # "Cannot fetch updates" while the bar module holds its lock. Each run now
  # gets a private CHECKUPDATES_DB, so the two cannot collide.
  mock_cmd checkupdates 'printf "linux 6.9 -> 6.10\n"'
  run "$BAR" updates --list
  assert_eq 0 "$status"
  assert_contains "$output" "linux 6.9 -> 6.10"
  assert_contains "$output" "archway update"
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

# The media pill shows the track, never the playback clock: a timer printed on
# the bar changed the pill width every second and slid the centred row around.
@test "bar media keeps the clock in the tooltip and out of the pill" {
  mock_cmd playerctl 'case "$*" in
    status) printf "Playing\n" ;;
    position) printf "37.0\n" ;;
    *mpris:length*) printf "2:40\n" ;;
    *playerName*) printf "firefox\n" ;;
    *artist*) printf "Tally Hall\n" ;;
    *title*) printf "The Bidding\n" ;;
    *) printf "\n" ;;
  esac'
  run "$BAR" media
  assert_eq 0 "$status"
  local text tooltip
  text=$(printf '%s\n' "$output" | sed -n 's/.*"text": "\([^"]*\)".*/\1/p')
  tooltip=$(printf '%s\n' "$output" | sed -n 's/.*"tooltip": "\([^"]*\)".*/\1/p')
  assert_contains "$text" "Tally Hall"
  [[ $text != *"0:37"* ]] || fail "the pill still prints the elapsed time"
  assert_contains "$tooltip" "0:37 / 2:40"
}

@test "bar media holds the slot with a placeholder when nothing plays" {
  mock_cmd playerctl 'exit 0'
  run "$BAR" media
  assert_eq 0 "$status"
  assert_contains "$output" '"class": "muted"'
  assert_contains "$output" "no media player is running"
}

# A click command that ends on its own closes the terminal it just opened, so
# both "show me this list" pills have to wait for a keypress on the tty that
# kitty gives them (waybar itself spawns the command with no usable stdin).
@test "bar click commands wait for a keypress instead of closing instantly" {
  local cfg="$ARCHWAY_ROOT/dotfiles/dot_config/waybar/config.jsonc"
  run grep -c 'read -r _ </dev/tty' "$cfg"
  assert_eq 0 "$status"
  assert_eq 2 "$output"
  run grep -c '"on-click": "kitty -e systemctl --failed"' "$cfg"
  assert_eq 1 "$status"
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

# ------------------------------------------------------------ password -----

@test "password status reports the tooling and the vault lock" {
  mock_cmd rbw 'case $1 in unlocked) exit 1 ;; lock) exit 0 ;; esac'
  mock_cmd rofi-rbw 'exit 0'
  run "$ARCHWAY_ROOT/applets/password/password.sh" status --json
  assert_eq 0 "$status"
  assert_contains "$output" '"installed":true'
  assert_contains "$output" '"unlocked":false'
  assert_contains "$output" '"picker":true'
}

@test "password --rofi copies through rofi-rbw with a clipboard timeout" {
  mock_cmd rbw 'case $1 in unlocked) exit 0 ;; esac'
  mock_cmd rofi-rbw 'printf "%s\n" "$*" >> "$HOME/picker.log"'
  mock_cmd notify-send 'exit 0'
  run "$ARCHWAY_ROOT/applets/password/password.sh" --rofi
  assert_eq 0 "$status"
  assert_file_contains "$HOME/picker.log" "--action copy"
  assert_file_contains "$HOME/picker.log" "--clear 30"
}

@test "password lock asks the agent to lock and never logs a secret" {
  mock_cmd rbw 'printf "%s\n" "$*" >> "$HOME/rbw.log"'
  mock_cmd notify-send 'exit 0'
  run "$ARCHWAY_ROOT/applets/password/password.sh" lock
  assert_eq 0 "$status"
  assert_file_contains "$HOME/rbw.log" "lock"
}

@test "password dry-run prints the picker command without opening it" {
  mock_cmd rbw 'exit 0'
  mock_cmd rofi-rbw 'printf "%s\n" "$*" >> "$HOME/picker.log"'
  run "$ARCHWAY_ROOT/applets/password/password.sh" --dry-run --rofi
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] rofi-rbw"
  assert_missing "$HOME/picker.log"
}

# ----------------------------------------------------------- bluetooth -----

_bt_mocks() {
  export BT_POWERED_FILE="$HOME/bt-powered"
  printf 'yes\n' > "$BT_POWERED_FILE"
  mock_cmd notify-send 'exit 0'
  mock_cmd timeout 'shift; "$@"'
  mock_cmd bluetoothctl 'case $1 in
    show) printf "Controller AA:BB:CC:DD:EE:00\n\tPowered: %s\n" "$(cat "$BT_POWERED_FILE")" ;;
    devices) printf "Device AA:BB:CC:DD:EE:01 Headphones\nDevice AA:BB:CC:DD:EE:02 Mouse\n" ;;
    info) [[ $2 == *01 ]] && printf "\tConnected: yes\n" || printf "\tConnected: no\n" ;;
    power) if [[ $2 == off ]]; then printf 'no\n' > "$BT_POWERED_FILE"; else printf 'yes\n' > "$BT_POWERED_FILE"; fi; printf "succeeded\n" ;;
    connect) printf "Connection successful\n" ;;
    disconnect) printf "Successful disconnected\n" ;;
    *) exit 0 ;;
  esac'
}

@test "bluetooth status lists the adapter and the connected devices" {
  _bt_mocks
  run "$ARCHWAY_ROOT/applets/bluetooth/bluetooth.sh" status
  assert_eq 0 "$status"
  assert_contains "$output" "bluetooth: yes"
  assert_contains "$output" "Headphones"
  [[ $output != *Mouse* ]] || fail "a disconnected device was reported"
}

@test "bluetooth status --json reports power and connections" {
  _bt_mocks
  run "$ARCHWAY_ROOT/applets/bluetooth/bluetooth.sh" status --json
  assert_eq 0 "$status"
  assert_contains "$output" '"powered":true'
  assert_contains "$output" '"connected":["Headphones"]'
}

@test "bluetooth power toggle flips the adapter" {
  _bt_mocks
  run "$ARCHWAY_ROOT/applets/bluetooth/bluetooth.sh" --power toggle
  assert_eq 0 "$status"
  assert_file_contains "$BT_POWERED_FILE" "no"
  run "$ARCHWAY_ROOT/applets/bluetooth/bluetooth.sh" --power toggle
  assert_eq 0 "$status"
  assert_file_contains "$BT_POWERED_FILE" "yes"
}

@test "bluetooth connect reports a failure instead of pretending" {
  _bt_mocks
  mock_cmd bluetoothctl '[[ $1 == show ]] && printf "\tPowered: yes\n" && exit 0
    printf "Failed to connect: org.bluez.Error.NotReady\n"'
  run "$ARCHWAY_ROOT/applets/bluetooth/bluetooth.sh" --connect AA:BB:CC:DD:EE:01
  assert_eq 1 "$status"
  assert_contains "$output" "could not connect"
}

@test "bluetooth dry-run prints the command and keeps the adapter state" {
  _bt_mocks
  mock_cmd bluetoothctl 'printf "%s\n" "$*" >> "$HOME/bt.log"
    [[ $1 == show ]] && printf "\tPowered: yes\n" && exit 0
    exit 0'
  run "$ARCHWAY_ROOT/applets/bluetooth/bluetooth.sh" --dry-run --power off
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] bluetoothctl power off"
  [[ $(cat "$HOME/bt.log") != *"power off"* ]] || fail "dry-run changed the adapter"
}

# ---------------------------------------------------------------- keyd -----

# The applet must be testable without root and without touching the real /etc:
# KEYD_DIR is the documented override for tests and non-standard installs.
_keyd_mocks() {
  export KEYD_DIR="$HOME/etc-keyd"
  unset KEYD_BIN
  export KEYD_BIN=keyd
  export POLKIT_RULE="$HOME/etc-polkit/49-archway-keyd.rules"
  mock_cmd keyd 'printf "%s\n" "$*" >> "$HOME/keyd.log"'
  mock_cmd notify-send 'exit 0'
  mock_cmd sudo '[[ $1 == -n ]] && shift
    [[ $1 == true ]] && exit 0
    "$@"'
  mock_cmd systemctl 'printf "%s\n" "$*" >> "$HOME/systemctl.log"
    case $1 in
      is-active) [[ -e "$HOME/active" ]] ;;
      is-enabled) [[ -e "$HOME/enabled" ]] ;;
      enable) touch "$HOME/active" "$HOME/enabled" ;;
      disable) rm -f "$HOME/active" "$HOME/enabled" ;;
    esac'
}

@test "keyd status reports a machine without keyd" {
  export KEYD_DIR="$HOME/etc-keyd"
  export KEYD_BIN=keyd-not-installed
  run "$ARCHWAY_ROOT/applets/keyd/keyd.sh" status --json
  assert_eq 0 "$status"
  assert_contains "$output" '"installed":false'
  assert_contains "$output" '"config":"missing"'
}

@test "keyd on installs the packaged layer and enables the service" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  run "$K" on
  assert_eq 0 "$status"
  assert_file_contains "$KEYD_DIR/default.conf" "capslock = overload(numpad, esc)"
  assert_file_contains "$HOME/systemctl.log" "enable --now keyd"
  run "$K" status --json
  assert_contains "$output" '"active":true'
  assert_contains "$output" '"config":"managed"'
}

@test "keyd on refuses to run when the package is absent" {
  export KEYD_DIR="$HOME/etc-keyd"
  export KEYD_BIN=keyd-not-installed
  mock_cmd notify-send 'exit 0'
  run "$ARCHWAY_ROOT/applets/keyd/keyd.sh" on
  assert_eq 3 "$status"
  assert_contains "$output" "pacman -S keyd"
}

@test "keyd off disables the service and keeps the layer file" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  run "$K" on
  run "$K" off
  assert_eq 0 "$status"
  assert_file_contains "$HOME/systemctl.log" "disable --now keyd"
  assert_file_contains "$KEYD_DIR/default.conf" "capslock = overload(numpad, esc)"
  run "$K" status --json
  assert_contains "$output" '"active":false'
}

@test "keyd toggle flips the service state" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  run "$K" toggle
  assert_eq 0 "$status"
  [[ -e $HOME/active ]] || fail "toggle did not start the service"
  run "$K" toggle
  assert_eq 0 "$status"
  [[ ! -e $HOME/active ]] || fail "toggle did not stop the service"
}

@test "keyd grant installs a narrow polkit rule and removes sudo from the toggle" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  # No cached credentials: the first grant still needs a password, which the
  # test fakes with pkexec. After it, nothing should ask again.
  mock_cmd sudo 'exit 1'
  mock_cmd pkexec '"$@"'
  mock_cmd pgrep 'exit 0' # a polkit agent is up, so pkexec can ask for the password
  run "$K" grant
  assert_eq 0 "$status"
  assert_file_contains "$POLKIT_RULE" 'subject.isInGroup("wheel")'
  assert_file_contains "$POLKIT_RULE" 'org.freedesktop.systemd1.manage-units'
  run "$K" toggle
  assert_eq 0 "$status"
  [[ -e $HOME/active ]] || fail "toggle did not start keyd after grant"
  run "$K" revoke
  assert_eq 0 "$status"
  [[ ! -e $POLKIT_RULE ]] || fail "revoke left the rule in place"
}

@test "keyd install never overwrites a config Archway does not own" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  mkdir -p -- "$KEYD_DIR"
  printf '[ids]\n*\n[main]\ncapslock = esc\n' > "$KEYD_DIR/default.conf"
  run "$K" install
  assert_eq 1 "$status"
  assert_contains "$output" "not managed by Archway"
  assert_file_contains "$KEYD_DIR/default.conf" "capslock = esc"
}

@test "keyd install --replace keeps the previous file as a backup" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  mkdir -p -- "$KEYD_DIR"
  printf '[ids]\n*\n[main]\ncapslock = esc\n' > "$KEYD_DIR/default.conf"
  run "$K" install --replace
  assert_eq 0 "$status"
  assert_file_contains "$KEYD_DIR/default.conf" "overload(numpad, esc)"
  run bash -c "ls \"$KEYD_DIR\"/default.conf.bak.*"
  assert_eq 0 "$status"
  assert_contains "$output" "default.conf.bak."
}

@test "keyd dry-run writes nothing" {
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  _keyd_mocks
  run "$K" --dry-run on
  assert_eq 0 "$status"
  assert_contains "$output" "[dry-run] systemctl enable --now keyd"
  assert_missing "$KEYD_DIR/default.conf"
  # Reading the state is fine; changing it is not.
  if [[ -r $HOME/systemctl.log ]] && grep -qE '^(enable|disable)' "$HOME/systemctl.log"; then
    fail "dry-run changed the service state"
  fi
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

@test "keyd explains a missing polkit agent instead of failing on /dev/tty" {
  # root never reaches pkexec, so the failure mode cannot be reproduced there
  ((EUID == 0)) && skip "needs a non-root shell"
  K="$ARCHWAY_ROOT/applets/keyd/keyd.sh"
  export KEYD_DIR="$HOME/etc-keyd"
  export KEYD_BIN=keyd
  mock_cmd keyd 'exit 0'
  mock_cmd notify-send 'exit 0'
  mock_cmd sudo '[[ $1 == -n ]] && exit 1
    exit 0'
  mock_cmd pkexec 'printf "prompted\n" >> "$HOME/pkexec.log"'
  mock_cmd systemctl 'case $1 in
      is-active | is-enabled) return 0 ;;
    esac
    exit 0'
  mock_cmd pgrep 'exit 1'
  run "$K" off
  assert_eq 3 "$status"
  assert_contains "$output" "no polkit agent is running"
  assert_missing "$HOME/pkexec.log"
}
