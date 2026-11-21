# Changelog

All notable changes to Archway are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `password` applet behind `Super+P`: rbw/rofi-rbw with a notification, a
  `--type username` option, `lock`, and a clipboard that clears after 30 s
  (`PASSWORD_CLEAR_SECONDS`). Secrets stay in the vault; the applet never logs
  them. Replaces the bare `rofi-rbw` binding.
- `bluetooth` applet behind `Super+Shift+B`: adapter on/off, scan, connect and
  disconnect through `bluetoothctl` in a rofi menu, plus `status --json` for the
  bar and `doctor`. Forgetting a pairing stays a manual, deliberate action.
- Second selectable theme, **Ember**: warm charcoal-brown surfaces with a peach
  accent and square corners. It is one `palette.toml` plus metadata — no app was
  touched — which is the point: `archway theme set ember` (or the Super+Space
  selector) recolours the whole desktop, GTK included.
- `keyd` applet and `Super+Alt+N`: turn the one-hand numpad layer on and off
  without touching `/etc` by hand. `on`/`off`/`toggle` only touch the systemd
  service (idempotent, no root kept around), `install` writes the packaged
  `applets/keyd/default.conf` and refuses a file Archway does not own unless
  `--replace` is passed, keeping `default.conf.bak.<timestamp>`, and `reload`
  applies an edit without a restart so a syntax error leaves the old mapping in
  place. Root comes from `sudo -n` when cached, otherwise `pkexec` through the
  polkit agent — the same command works from a keybind and a terminal. The
  package is in the desktop manifest but the service stays off until asked.
  `docs/keyd.md` now documents the applet instead of manual root edits.
- Desktop baseline gaps that made existing shortcuts fail silently: `firefox`
  (behind `Super+B`), `power-profiles-daemon` (gaming applet and the power
  pill), `wl-clip-persist` (copied text survives the app that made it),
  `hyprpicker`, `zathura` with the MuPDF backend, and `tailscale` for the VPN
  pill.
- `developer` manifest: `just` (the repo's own justfile), `gdb` and `strace`
  for native crashes, `hurl`, `kubectl`/`helm` (k9s could not reach a cluster),
  and `difftastic` next to `delta`.
- `window` applet and `Super+Shift+F` as **almost fullscreen**: the window fills
  the whole work area (monitor minus the bar's reserved space) so the bar and
  its icons stay visible, and pressing it again returns to the layout. True
  fullscreen stays on `Super+F`. Measured on 1366x768: maximize is 1348x720 at
  `9,39`, fullscreen is 1366x768 at `0,0`. Toggle floating moved to
  `Super+Alt+F`, which also fixes the old key doing two unrelated things.
- `gaming` applet and the rocket pill in the bar: one switch for performance
  power profile, do-not-disturb and paused `hypridle` (SIGSTOP, not killed), all
  restored on the way out. Right click on the pill still cycles the power
  profile. `Super+Alt+G` toggles it too. No root, no service changes.
- `archway applet terminal --pick | --set | --print`: choose the default
  terminal (kitty, alacritty, ghostty, wezterm, foot) from rofi or the CLI; the
  choice is stored in `~/.config/archway/terminal` and survives sessions.
  `Super+Ctrl+Return` opens the picker. Added an `alacritty` theme module, so an
  existing `alacritty.toml` can import
  `~/.config/archway/theme.d/alacritty-theme.toml`; the config file itself stays
  user-owned because many people (including this repo's owner) already run a
  customised one.
- Thunar as the file manager behind `Super+E` (Yazi moved to `Super+Alt+E`),
  with a curated `thunar.xml` (details view, folders first, thumbnails, volume
  management on, single click off), six custom actions (open terminal here, open
  in yazi, edit with Neovim, copy path, extract here, refresh thumbnails) and the
  packages that make them work (`thunar-volman`, `thunar-archive-plugin`,
  `tumbler`, `ffmpegthumbnailer`, `poppler-glib`, `file-roller`).
- `Super+Tab` opens the rofi window switcher.
- `docs/keyd.md`: the one-hand numpad layer (CapsLock tap = Esc, hold = numpad),
  install/reload/test steps, the optional navigation layer, known interactions
  with games and other remappers, and how to remove it.
- `custom/media` pill: real elapsed/length time from `playerctl`, refreshed every
  second, next to the media title.

- `terminal` applet, now behind `Super+Return`: the new terminal opens on the
  side of the workspace the cursor is on (`left`, `right`, `up`, `down`), not on
  the side dwindle guesses from the focused window, which turned a bottom-of-
  screen spawn between two side-by-side terminals into a thin column. When the
  pointer stays in the middle band nothing is forced and dwindle decides as
  before.
- **Nine monochrome themes** next to the flagship palette: `mono-blue`,
  `mono-teal`, `mono-green`, `mono-yellow`, `mono-orange`, `mono-red`,
  `mono-pink`, `mono-purple` and `mono-slate`. Application templates moved to
  `themes/_shared/`, so a variant is a palette plus metadata instead of ten
  copies of every CSS file. `archway theme list --names` shows the display
  name, and the rofi selector reads it.
- Applets: `network` (rofi Wi-Fi menu with signal/lock icons, radio toggle,
  rescan and password prompt), `wallpaper` (`hyprpaper`, `Super+Alt+W`,
  restored at session start), `clipboard` (starts the `wl-paste` watcher that
  `cliphist` needs) and `osd` (volume/mic/brightness with `swayosd`, a narrow
  notification only as fallback).
- **Grouped waybar layout**: each cluster is one pill — launcher + workspaces +
  context | media + clock + notifications | alerts | connectivity | resources |
  controls | session. New modules: `mpris`, notification count with do-not-disturb,
  privacy (mic/camera/screen share), screen recording, failed units, pending
  updates, locked vault, VPN/Tailscale, CPU/RAM/temperature, low disk, night
  light, keyboard layout, idle inhibitor, power profile. Alert pills appear
  only when they have something to say; CPU/RAM/temperature, disk and night
  light always keep their icon and fade to muted when healthy, so nothing the
  eye learned to look for silently disappears.
- `archway-bar`, a small helper installed next to the CLI, backs the bar modules
  that need real logic (13 sections, each printing one waybar JSON object).
- waybar modules carry Nerd Font icons and state-driven colours from the
  palette: neutral when healthy, muted when off, green charging, amber warning,
  red critical.
- `swayosd` and `cliphist` in the desktop manifest, `papirus-icon-theme` for
  rofi/waybar icons.

### Changed

- **keyd moved to `Super+Alt+N`** and the applet reports what it actually did.
  `Super+Ctrl+K` was a bad chord: if the bind is not loaded (a session running
  an older config, a failed reload) the keypress is forwarded to the focused
  window, and Ctrl+K is readline's kill-line, so it ate text in terminals
  instead of failing visibly. `archway doctor` now asks `hyprctl binds` what the
  running session loaded (`keybinds.loaded`) and names the chords that are
  missing, which turns that whole class of bug into one line of output.
- GTK3 is now a theme module: `themes/_shared/gtk/gtk.css` recolours every GTK3
  app from `palette.toml` (window/sidebar/list surfaces, selection, focus
  outline, square corners) and is published as `~/.config/gtk-3.0/archway.css`,
  imported by the tracked `gtk.css`. Thunar, file dialogs and the rest of the
  GTK stack now follow the active theme instead of a separate GTK theme.
- Thunar is tuned for a keyboard-first 1366x768 laptop: details view with ISO
  dates, folders first, single click off, name/size/type/modified columns, path
  entry instead of breadcrumbs, `LOCAL_ONLY` thumbnails and a delete action in
  the menu (`dotfiles/dot_config/Thunar/thunar.xml`).

- Workspaces now show where the windows are: a workspace with windows keeps
  full-brightness text plus a `primary` hairline under the number, an empty one
  fades to muted, and the active one keeps the filled pill. The hairline is a
  box shadow, so the buttons do not change size.

- The bar row no longer moves. The active workspace button only changes colour
  (its 1 px margin made one button wider and slid the row), the window-title and
  media pills keep a fixed footprint (`min-width`), `custom/nowplaying` holds the
  media slot while no player is running, and the notification bell stays visible
  with a zero count. The row is therefore the same width in every state, which
  keeps both edges flush at 8 px on a 1366 px screen and stops re-centring.

- Focus ring is a single flat hairline on the active window: `border_size`
  stays 1 but the two-colour gradient became one solid `primary` line, and the
  ring on unfocused windows is fully transparent. `inactive_opacity` is 1.0 and
  the palette `opacity` is 1.0, so an unfocused window is neither dimmed nor
  washed out — focus is carried by the line alone.
- kitty has no inner padding any more: the 12 px band was painted in the
  terminal background colour and showed as a ghost frame around Neovim, whose
  own background differs. Text and Neovim now reach the 1 px window border, and
  nothing is added outside it either.
- Firefox is square too: a `firefox-square` window rule drops the compositor
  rounding for `firefox`, `firefox-esr` and `librewolf`, whose surfaces are
  drawn edge to edge and looked cut into arcs.

- Terminals are square and opaque. A window rule sets `rounding = 0` for
  `kitty`/`floating-term`/`alacritty`/`foot`, and kitty goes back to
  `background_opacity 1.0`. Rounded corners plus a translucent background drew
  a faint arc of border over the first cells of the grid, which looked like a
  phantom frame inside Neovim.

- Workspaces are capped at six: `Super+7/8/9` and their `movetoworkspace`
  counterparts are gone from `keybinds.toml`, and waybar reserves exactly six
  workspace pills. Six is the most that fits next to the status cluster on a
  1366 px screen, so the session counter can no longer grow the row off screen.

- Tighter waybar geometry: smaller pill padding and gaps, narrower
  workspaces, status modules and window title, so the bar reads as dense
  instead of airy. The media pill moved next to the window title: what is
  playing is context for the same workspace, not a separate centre block. The
  clock and notifications follow it in the same left row, so spacing stays
  uniform and the row reflows when a title or the track name grows instead of
  leaving a fixed gap around the centre. The status cluster is no longer
  anchored to a single edge: it is one centred row of three zones
  (session/shell, identifiers, status) separated by an 18 px break, with pills
  inside a zone spaced 6 px apart. Centring keeps the two insets equal on any
  screen width instead of leaving a void on wide monitors. The clock always
  shows date + time (`20/11 18:57`), so clicking it does not change the row
  width, and workspaces are capped at six, which was what pushed the row past
  the screen edge before.

- **The desktop is now Hyprland on Wayland**, started through `uwsm`; X11/bspwm
  is out of scope. Packages, profiles, applets, keybinds, theme modules and the
  session config were migrated: `hypr`, `waybar`, `swaync`, `hyprlock`,
  `hypridle` and `hyprpaper` replace `bspwm`, `sxhkd`, `polybar`, `dunst`,
  `picom` and `i3lock-color`.
- Keybinds now generate native Hyprland `bind`/`binde` lines with dispatchers
  (`killactive`, `movefocus`, `workspace`, ...) instead of shelling out to
  `bspc`. Media keys use `binde` so holding them repeats.
- Clipboard, screenshots and locking are Wayland-native: `cliphist` + `wl-copy`,
  `grim`/`slurp` + `wl-copy`, `hyprlock`.
- `desktops/hyprland/compat.toml` declares the supported Hyprland range and
  `archway doctor` warns when the running compositor is older than the minimum
  or newer than the tested version (ADR-014).
- The theme publishes `waybar/theme.css` and `swaync/theme.css` next to their
  configs, and drives Hyprland/hyprlock colours through `@key:hex@` tokens for
  ARGB syntax.
- `archway install` rejects any compositor other than `hyprland` instead of
  silently planning an unsupported desktop.
- **Hyprland 0.57 replaced hyprlang with a Lua configuration API.**
  `hyprland.lua` and `conf.d/20-keybinds.lua` replace the `.conf` files, the
  theme renders `hl.config({ ... })` instead of key=value colour blocks, and
  the keybind generator emits `hl.bind("SUPER + SHIFT + Q",
  hl.dsp.window.close())`. Dispatchers are mapped in one place, so an unknown
  name fails generation instead of producing a bind that does nothing.
- `archway doctor` now runs `Hyprland --verify-config` against the generated
  config and fails on a parse error, which is how a hyprlang leftover is caught.
- `archway theme set` prunes generated artifacts for targets the theme no
  longer ships, so a stale `theme.d/hyprland.conf` cannot linger.
- A `swaync-client -rs` reload no longer blocks the installer when no swaync
  daemon is running, and a Neovim theme-contract failure no longer cancels the
  rest of the install.
- **Waybar is compact and quiet**: 30 px tall, smaller paddings, window title
  secondary, no transitions. Hyprland ships without animations, blur or
  shadows, with 4/8 px gaps and VFR enabled — the desktop is tuned for latency
  on laptop GPUs, not for movement.
- Touchpad and mouse are configured separately: natural scroll on the
  trackpad, classic wheel direction on mice (`hl.device` rule included).

### Fixed

- An existing `~/.config/alacritty/alacritty.toml` is no longer replaced: the
  first attempt at the terminal selector shipped one, and chezmoi overwrote a
  customised config (restored from the backup; the file is now out of the repo).
  Only the theme module is generated.
- Every window is square (`square-windows` rule, `rounding = 0` for all classes):
  a compositor-rounded corner arcs the border over the first cells of the
  content, which shows as a frame inside terminals, editors and browsers.
- **Themes reach open terminals.** `archway theme set` now sends the new colours
  (and a config reload) to every kitty listening on
  `/tmp/kitty-archway-<pid>`; before, it only worked from a kitty shell, because
  it relied on `KITTY_LISTEN_ON`, which the applet launched from a keybind or
  rofi never inherits. Running terminals now change theme without restarting.
- **Wallpapers apply again.** hyprpaper 0.8 dropped the `hyprctl hyprpaper`
  requests Archway used (`preload`, `unload`): every apply failed with
  "invalid hyprpaper request". The applet now uses the two requests that still
  exist (`wallpaper`, confirmed with `listactive`) and persists the choice in the
  0.8 `wallpaper { monitor = / path = / fit_mode = }` block syntax, so the last
  wallpaper also comes back at session start.
- Bar button that looked dead: the pending-updates pill stays visible when the
  system is up to date (muted check instead of a hidden module), and its click
  opens the real `checkupdates` list instead of a dry-run.
- Media tooltip no longer shows `00:00:00` forever (waybar's `{position}` is not
  reported by several players); the elapsed pill next to it asks `playerctl`.
- Clock no longer flickers between two widths on repeated clicks: `format-alt`
  was toggled by every left click and is gone.
- Notification control centre is a square sheet flush to the screen edge
  (right and bottom margins 0, right corners square) instead of a rounded card
  floating with a strip of wallpaper around it.
- Terminal rendering of `==`, `==>`, `>=`, `<=` and `->`: ligatures are disabled,
  so two-character operators stay two characters in kitty and in Neovim instead
  of turning into arrows and math glyphs.
- Touchpad scrolling in Neovim: `pixel_scroll no` plus
  `touch_scroll_multiplier 1.0`. kitty >= 0.46 turns Wayland gestures into pixel
  deltas with its own momentum, which kept scrolling after the fingers stopped
  and made wheel-up at the end of a markdown buffer look ignored.
- kitty is translucent (0.92) with fully opaque text, and terminals stay square,
  so the wallpaper shows through without a ghost frame over the grid.

- The touchpad lost its right click: `input.touchpad.clickfinger_behavior` was
  on, so a physical press counted fingers instead of using the button areas and
  a one-finger press on the right button arrived as a left click. The option is
  gone and `tap_button_map` is pinned to `lrm` (one finger left, two right,
  three middle).
- Most `Super` shortcuts did nothing: Hyprland starts without `~/.local/bin` on
  `PATH`, so the generated binds' bare `archway` call failed silently while
  `kitty` worked. Binds now use `$HOME/.local/bin/archway` and `archway install`
  keeps that link (plus `archway-bar`) up to date.
- `Super+D` printed "binding Control+k / Tab is already bound": `config.rasi`
  re-declared rofi's own defaults. The overrides are gone.
- `Super+/` flashed open and closed; the cheatsheet is now a rofi menu instead
  of a pager in a terminal that exits immediately.

- New terminals no longer take over the workspace: Hyprland now suppresses
  `maximize` requests (`suppress-maximize-events`), which kitty was sending on
  map.
- `Super + Space` registered as a lowercase `space` keysym that Hyprland could
  not bind; the generator canonicalises keysym names (`Space`, `Escape`,
  `Prior`, ...) and a test covers it.
- `archway install --yes` no longer aborts when a managed dotfile was deleted:
  targets reported as removed are restored with a scoped `--force` instead of
  asking for a TTY that `--yes` does not have.
- The stale-artifact prune maps a target to its real source path
  (`.config/zsh/.zshrc` -> `dot_config/zsh/dot_zshrc`); the previous mapping
  missed dot-prefixed file names and deleted the live `.zshrc` on every install.
  Covered by two regression tests.
- `yazi` (bound to `Super+E`) and `swayimg` are now in the desktop manifest;
  the file-manager keybind previously pointed at a package Archway never
  installed.

- Read-only commands (`doctor`, `theme validate`, `keys check`, `pkg check`)
  now run as root, so CI containers can use them. Only mutating commands
  refuse root.
- `doctor` no longer reports a user's existing Neovim checkout as a critical
  failure when Archway does not manage it; it is a warning until ownership is
  recorded by `archway nvim install`.

## [0.1.0] — Mount

First functional skeleton. The desktop slice is `bspwm` on X11 with `kitty`,
`zsh`, `tmux`, `polybar`, `rofi` and `dunst`, themed by **Android Mount**.

### Added

- `archway` CLI with stable exit codes, `flock` locking, timestamped logs,
  XDG state/config/cache/data layout and a plan-by-default `install`.
- `install`, `update`, `rollback`, `doctor`, `theme`, `nvim`, `pkg`, `keys`,
  `applet`, `backup`, `restore`, `uninstall`, `version`, `pin` and `self-update`.
- Named keybind conflict resolution: AGENTS.md bound `Super+L` to both focus-east
  and lock; navigation keeps `Super+L`, locking moved to `Super+Escape`, and
  `archway keys validate` now catches that class of mistake.
- Incremental updates: `archway update` fast-forwards a single checkout and
  lets `chezmoi apply` touch only files whose content differs. Re-cloning on
  each machine is never required.
- Android Mount theme (`themes/android-mount/`) with a hand-written palette,
  WCAG-AA contrast validation, renderer and per-app templates for kitty,
  bspwm, polybar, rofi, dunst, tmux, starship, fzf and bat.
- Neovim integration contract: `deps/nvim-config.lock`, `archway nvim`
  (`install`, `pin`, `status`, `doctor`, `rollback`) and the local
  `lua/archway.lua` hook. Archway never edits tracked Neovim files.
- Single-source keybinds (`keybinds/keybinds.toml`) generating `sxhkdrc` and
  `docs/keybinds.md`, with duplicate/reserved-combination validation.
- `android-mount` applet (simple-mtpfs, no `sudo`, safe mount points).
- Profile and package manifests (`minimal`, `developer`, `security`, `full`).
- `bats` tests, container-friendly CI workflow and contributor docs.

### Known limitations

- `deps/nvim-config.lock` ships as a **placeholder**: a human must run
  `archway nvim pin <tag>` against the real upstream repo before Neovim can be
  installed. Until then the desktop install still succeeds and `doctor`
  reports the Neovim pin as unverified.
- Hyprland is v0.2. The keybind and theme generators are stack-agnostic but
  only the X11 outputs are emitted today.
- `archway uninstall` restores backups and removes managed links; it does not
  remove packages (documented in `docs/uninstall.md`).
