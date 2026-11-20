# Changelog

All notable changes to Archway are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

- Tighter waybar geometry: smaller pill padding and gaps, narrower
  workspaces, status modules and window title, so the bar reads as dense
  instead of airy. The media pill moved next to the window title: what is
  playing is context for the same workspace, not a separate centre block.

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
