# Changelog

All notable changes to Archway are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Workflow helpers for projects and labs: `zi` (zoxide picker), `loadenv`
  (per-project `.env` with a permissions warning, values never printed) and
  `passgen` (kernel CSPRNG password).
- The `fzf-tab` preview works for any command (`ls dir/`, `nvim dir/`, `vi`,
  `nano`): directories open as an `eza` tree and files as a `bat` preview.
- tmux keeps the stock `C-b` prefix and 0-based window numbers, so `C-b c/n/p`,
  `C-b 0..9`, `,`, `%`, `"`, arrows, `x`, `z`, `d`, `[` and `?` all behave as
  documented; `C-b C-b` sends a literal `C-b` and splits reuse the pane path.
- The Ctrl-T (files) and Alt-C (directories) `fzf` pickers use the theme's
  colours, `Files`/`Directories` and `Preview` border labels, a header with the
  keys, `--multi` selection and `bat`/`eza` previews.
- `fzf-tab` uses the reference rice's three-pane layout (`Search`, `Results`,
  `Preview`) with coloured borders, `>` pointer and `eza`/`bat` previews.
- The prompt colours the git icon purple, the branch name yellow and dirty
  markers orange; command duration stays muted so the line keeps a hierarchy.
- atuin's picker uses the reference layout by default: compact style with
  `Search │ Inspect` tabs, the `GLOBAL` filter line, duration and relative time
  per command, and a four-line preview of the highlighted entry.
- Tab completion in an `fzf` pane via `fzf-tab` when the plugin is installed
  (`fzf-tab-git`, added to `packages/aur-core.txt`). It loads after `compinit`
  and after `FZF_DEFAULT_OPTS`, so the completion picker uses the active theme's
  colours; without the plugin zsh's built-in menu is unchanged.
- Vi editing mode in the zsh line editor (`conf.d/05-keymap.zsh`), with
  `keymap vi|emacs` to switch and persist the choice. Arrow keys keep the same
  behaviour in both modes and keymaps (prefix-aware history, word jumps on
  Ctrl+Left/Right, Home/End), command mode gets `u`/`^R`/`v` and a block
  cursor, and the prompt double chevron turns yellow (`❯❯`) while not inserting,
  green   (`❯❯`) otherwise. Backspace is rebound in command mode, where zsh only moved
  the cursor, and the terminal-standard readline keys (`^A`, `^E`, `^K`, `^U`,
  `^Y`, `^L`) are restored in insert and emacs modes, where zsh's vi insert
  left them as self-insert. The `-- NORMAL --` message line was removed: repainting it on
  every Esc/i ate the output above the prompt. The module stays safe when
  sourced without ZLE.
- Credential-aware history (`conf.d/35-history.zsh`): the history file moves to
  `~/.local/state/zsh/history`, a `zshaddhistory` hook drops commands carrying
  `Authorization:`, `--password`/`--token`, `export *_TOKEN=` or private-key
  headers, and atuin's filter list matches. `rec` records a timestamped
  transcript for audits and `rec-ls` lists them.
- `fcd` (fzf directory jump), `dns` (A/AAAA/MX) and `venv` (project-local
  virtualenv) helpers, plus prompt context for exit codes, root/SSH identity,
  containers, the active virtualenv and `tun0`/`wg0` VPN addresses.
- Terminal workflow helpers in `~/.config/zsh/conf.d/40-workflow.zsh`:
  `croot`, `serve` (loopback only), `killport`, `fkill`, `status`, `headers`,
  `cert`, `json`, `sha`, `b64e`/`b64d`, `urlenc`/`urldec`, `jwt` (local decode,
  no verification), `now`/`epoch` and `extract`. Every dependency is optional
  and nothing performs offensive automation; `docs/terminal.md` documents them.
- `archway install` now links the zsh `ZDOTDIR` loader by default (backup +
  marked line in `~/.zshenv`), because without it `~/.config/zsh` was never
  read and an old `~/.zshrc` silently won. `--no-link-shell` opts out, and
  `archway doctor` now warns when the loader is missing or when tracked
  dotfiles differ from what is applied (`chezmoi status`, read-only).
- New `jan` theme: the CyberPunk palette of `gh0stzk/dotfiles`'
  `config/bspwm/rices/jan`, reproduced exactly on Archway's Hyprland + Waybar
  stack. Kitty gets the reference's 16 ANSI slots verbatim, and the status line
  keeps Archway's module order but becomes one flush, full-width Waybar strip
  with no gaps or rounded pills. Theme-specific geometry now lives in
  `themes/<id>/overrides/<module>`, appended after the shared stylesheet, so a
  variant no longer copies (and drifts from) the whole CSS.
- The `jan` status line uses the reference bar's colour language: Wi-Fi green
  when connected and red when offline or degraded, Bluetooth blue, plus a
  restrained accent per module family. Its focus border is a 1 px cyan hairline
  at 35% alpha, and tighter gaps (`gaps_in 3`, `gaps_out 5`) give windows more
  room; the floating terminal grows to `85% 72%`. Palettes now accept optional
  `focus_alpha`, `gaps_in` and `gaps_out` keys with backward-compatible
  defaults, so existing themes render exactly as before. The window title and
  normally-dim icons (colour picker, language, night light, resources, gaming,
  keep-awake) use readable palette colours now, and the volume OSD is repainted
  by the same theme when its server restarts.
- The shared starship prompt reports the command duration from 100 ms (with
  milliseconds) instead of 800 ms, so timing a script while writing it does not
  need a stopwatch. It renders as muted text on the terminal background rather
  than as a filled block.
- The starship prompt is flat: all segment backgrounds (`bg:` fills, purple git
  blocks and the like) are gone, so modules read correctly over a transparent
  terminal or a wallpaper. Git uses the nerd-font branch glyph `` plus the
  branch name and status marks on the terminal background.
- `color-picker` applet (`Super+Alt+C` and an eyedropper pill in the bar):
  picks a pixel, copies it as `#RRGGBB` once, and shows a notification with the
  hex, the RGB triple and a swatch of the colour. `hyprpicker`'s zoom lens is
  the default backend; without it the applet falls back to `slurp -p` plus a
  1x1 `grim` grab. `--json`, `--no-copy` and `--dry-run` included, cancelled
  picks exit `4`.
- Firefox chrome rebuilt against the full palette: every colour is a token, so
  a theme switch repaints tabs, menus, suggestions and panels; accent marks
  focus, the active tab, the selected suggestion and download progress;
  `selection_bg` marks hover and selection; `tertiary` flags a tab asking for
  attention, `secondary` marks private windows, and `success`/`warning`/`error`
  are reserved for site identity, infobars and the close button. Also themed:
  window controls, find bar with a not-found state, downloads panel, private
  browsing, reader button, sidebar headers and `color-scheme: dark`.
- `archway applet firefox`: renders `chrome/userChrome.css`,
  `chrome/userContent.css` and a `user.js` from the active theme palette, with
  a backup of whatever it replaces. Square chrome, monochrome toolbar, dense
  tabs and `about:` pages only in `userContent.css` (web content keeps its own
  colours). `docs/firefox.md` covers the details.
- New theme modules: `zathura`, `mpv` and `lazygit`. The first two are `include`d
  by their configs; lazygit merges its theme through `$LG_CONFIG_FILE`, so
  `archway theme set` now repaints all three instead of leaving them on a
  hardcoded palette.
- Configs for the tools that had none: `zathura`, `mpv` (`mpv.conf` +
  `input.conf`), `imv`, `lazygit`, `tealdeer`, `fastfetch`, `ripgrep`, `mise`,
  `git` (delta, `zdiff3`, `rerere`, histogram diffs) and an SSH snippet at
  `~/.config/archway/ssh_config` that `~/.ssh/config` includes. `less` and `man`
  now go through `bat` with `MANROFFOPT=-c`, and `LESSHISTFILE=-` stops `less`
  writing a keystroke log. See `docs/cli-tools.md`.
- Thunar: the rc was extended (tabs always visible, CSD off so Hyprland draws
  the square frame, local-only thumbnails with a size cap, recursive search,
  `Ctrl+scroll` zoom) and the action menu gained *View Image* (imv),
  *Play with mpv* and *Read in zathura*.
- `hypridle` now stages screen-off / warning / lock / suspend, and `hyprlock`
  adds the user, a key hint and PAM login auth on top of the generated theme.
- `xdg-desktop-portal/portals.conf` pins `FileChooser` to the GTK backend, and a
  Hyprland window rule floats and centres portal dialogs.
- `imv` and `easyeffects` added to the desktop manifest.
- `doctor` now reports `keyd.grant`: when `keyd` is installed but the narrow
  polkit rule is missing, `Super+Alt+N` will raise an authentication dialog on
  every toggle (or fail when no agent is running), and the check says so with
  the one command that fixes it. `docs/keyd.md` explains why this uses a polkit
  rule instead of a setuid helper or a `NOPASSWD` sudoers line.
- `archway nvim pin --commit <sha>`, plus the first real pin: the lock now
  records commit `e309ab9` of `nvim-config` with the SHA256 of its archive.
  Upstream has no tags yet, and pinning by tag was the only option the CLI
  offered, so `unpinned = true` could not be cleared without inventing a tag.
  A full 40-character SHA is just as reproducible; the lock keeps `tag = ""`
  and `channel = "edge"` to say where it came from, and `nvim install` already
  cloned and checked out a commit.
- The project files the repository was missing: `SECURITY.md` (private
  reporting, what is in scope, how secrets are handled), `CONTRIBUTING.md`,
  `.gitleaks.toml`, `.pre-commit-config.yaml` (secret scan, shellcheck, shfmt,
  markdownlint, typos), `.github/dependabot.yml`, `.markdownlint-cli2.yaml`,
  `.yamllint.yml` and `.typos.toml`.
- CI now lints markdown, YAML, workflows and spelling (`markdownlint-cli2`,
  `yamllint`, `actionlint`, `typos`) and pins `actions/checkout` to the commit
  behind `v4.2.1` instead of a mutable tag. `corner3.png` moved out of the
  repository root to `docs/assets/`.
- `theme-selector --rofi`: `Super+Space` now opens the picker directly instead
  of asking rofi for a `-show theme` mode. That mode was declared by embedding a
  quoted shell command in a TOML value, and one escaping layer was double-escaped
  into `-modi \"theme:...`, so rofi answered "mode theme not found". The menu
  lists display names only (a tab is drawn as a column separator) and maps the
  chosen row back to its exact id.
- `emoji` applet behind `Super+.`: a rofi picker over ~300 curated emojis with
  English and Spanish keywords, most-recent-first ordering
  (`~/.local/state/archway/emoji-recent`) and `wl-copy` straight into the
  clipboard. Rows use one space between fields because rofi 2.x splits on
  whitespace runs, and a test enforces it.
- `record` applet behind `Super+Shift+R`: `wf-recorder` behind
  `status`/`start`/`stop`/`toggle` with `--region` (slurp selection), `--audio`,
  `--json` and `--dry-run`. Files land in `~/Videos/Recordings`; pid and path
  live in `~/.local/state/archway/record` so a second press finds the running
  recorder, `stop` sends the SIGINT wf-recorder needs to finalise the container
  and waits instead of killing it, and the bar's existing recording pill needs
  no new module. A recorder that dies on start is reported immediately with the
  log tail instead of leaving an empty file behind.
- Yazi is a theme module: `themes/_shared/yazi/theme.toml` maps the manager,
  tabs, mode, status, popups and file-type colours to `palette.toml` and is
  published as `~/.config/yazi/theme.toml`; a pre-existing file is copied to
  `~/.local/state/archway/backups/<timestamp>/yazi-theme.toml` the first time
  and named on screen, since Yazi has no include. Powerline separators and pill
  padding are gone (square), icons are left to the terminal font, and the
  hovered row in the preview pane is filled instead of underlined — that
  underline inherited the file-type colour and showed as a stray blue line in
  the right-hand panel.
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

- Firefox's security icons (lock, shield, broken lock) are the only toolbar
  icons exempt from the monochrome filter: https is `success`, blocked trackers
  `primary`, mixed content `warning` and a broken connection `error`. The
  selectors come from this build's `identity-block.css`, and the warning SVG's
  `fill: unset` is overridden so all three variants share the palette.
- The Bluetooth pill no longer prints "on"/"off": the glyph says what it is
  and the colour says the state — muted when off, full text when powered on,
  accent when a device is connected. Clicking it opens the Archway Bluetooth
  menu instead of `blueman-manager`.
- `archway keys generate` now delivers the chords to the running session: it
  copies the generated file to `~/.config/hypr/conf.d/20-keybinds.lua`, keeps the
  chezmoi source in step and reloads Hyprland. Until now it wrote only the
  checkout, so a new bind existed in the repo and in the tests but never in the
  compositor — which is why the keyd chord looked dead and Ctrl+K reached
  readline. `doctor` now distinguishes a stale live file ("run archway keys
  generate") from a session that just needs `Super+Alt+R`.
- Hyprland starts `hyprpolkitagent` with the session. Without a polkit agent
  `pkexec` falls back to its textual agent and dies on `/dev/tty` when launched
  from a keybind, so `Super+Alt+N` could not turn keyd off while the same command
  worked in a terminal. The keyd applet now says so explicitly (exit 3) instead
  of reporting a generic failure.
- **`archway applet keyd grant`** is the actual fix for toggling the numpad
  from a shortcut. A keybind has no terminal and no guarantee that a polkit
  agent is up, so the applet now installs one narrow rule
  (`/etc/polkit-1/rules.d/49-archway-keyd.rules`: `keyd.service` only, start/
  stop/restart/reload only, local active `wheel` sessions only) and then calls
  `systemctl` directly. `revoke` removes it. `reload` falls back to a service
  restart when only the rule is available, since `keyd reload` needs its root
  socket.
- `archway doctor` gains `theme.yazi`: it compares the generated Yazi theme with
  the live one, so a stale `theme.toml` (the app silently keeping the previous
  palette) is one line of output instead of a mystery.
- Sending a window to a workspace no longer follows it: `Super+Shift+4` moved the
  session to workspace 4 instead of moving the window there, because the
  generated bind used `hl.dsp.window.move({ workspace = N })`. Binds now emit
  `follow = false` (Hyprland's `movetoworkspacesilent`).
- The Wi-Fi menu is rebuilt around a rofi 2.x quirk: dmenu splits a line into
  columns on runs of whitespace, so the old tab/`-display-columns 3` rows showed
  a signal glyph on the left and truncated SSIDs on the right. Rows are now one
  space between fields with a fixed-width four-dot signal meter, the selection is
  read back with `-format i` and an action array (no parsing of visible text),
  nmcli's column padding is trimmed, and the password prompt is a single-line
  dialog (the SSID as prompt, masked entry) instead of an eight-row empty list
  with a cramped input.
- Thunar's remaining bright edges are gone: the menubar/toolbar, list column
  headers, treeview row separators and the scrollbar slider no longer inherit
  gradients or light borders from the stock GTK theme, the scroll edge shadows
  are flat, and the breadcrumb buttons are transparent until hovered with the
  current folder marked in accent text instead of a solid block. Sidebar rows and
  their labels get explicit text and selection colours.
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

- Path arguments complete again under `fzf-tab`: carapace returns candidates
  without the typed prefix, which left the picker empty, so it is now opt-in
  (`ARCHWAY_CARAPACE=1`).

- `Ctrl+R` opens atuin again: `fzf --zsh` binds that key, so atuin's
  integration now loads after fzf instead of before it.

- The colour picker copied nothing under the real `hyprpicker`: the applet
  passed `-q`, and hyprpicker prints the picked colour through
  `Debug::log(NONE, ...)` — quiet drops every level but `ERR`/`CRIT`, so the
  colour never reached stdout and the applet treated the empty result as a
  cancelled pick. `-q` is gone, `-b` keeps the output plain, and the escapes are
  stripped too. Failures are also logged to
  `~/.local/state/archway/logs/color-picker.log`, since a keybind run has no
  visible stderr.
- The address-bar suggestions no longer wear a grey frame. Firefox paints the
  lower half of the open field (`.urlbarView-background`) with
  `1px solid var(--panel-border-color)` plus a shadow; the frame and the shadow
  are gone and the field's `surface` continues through the dropdown. The
  separators, hover and selected colours inside the list now come from the
  palette instead of Firefox's grey ramp.
- Gaming mode no longer appears to switch itself on after a reboot. The mode
  stamps the kernel boot id in `gaming.state`; `gaming reconcile` (run at
  Hyprland session start and by `gaming status`) undoes a mode left over from a
  previous boot: saved profile restored, DND back to its saved value, `hypridle`
  resumed. `power-profiles-daemon` persists its profile across boots, which is
  why a shutdown with the mode on came back as `performance` with no state.
- The file chooser did not show what was selected: Ctrl+click really selected
  files (they uploaded), but no row was highlighted. The GTK theme only painted
  `treeview.view:selected:focus`, and a selection built with the keyboard
  focus elsewhere never matched it. `:selected`, `:selected:backdrop` and the
  hovered variants are now styled for views, icon views and lists, with a 2px
  accent bar on the selected row.
- Firefox could not be closed: the prefs set
  `browser.tabs.closeWindowWithLastTab = false`, so the X on the last tab left
  an empty window that never went away. It is `true` again.
- The address bar kept a frame around its suggestions: the 1px border lived on
  `#urlbar-background`, which also wraps the open dropdown. The field is
  borderless now, focus and the open list are marked by a one-pixel line under
  it, and nothing inside draws an outline.
- Firefox drew a square inside a square: the chrome stylesheet put a 1px
  border on `menupopup`/`panel` *and* on the content part Firefox paints inside
  them, so every context menu, panel and the search dropdown showed two nested
  frames. Only the outer content part is framed now, menus get the fill alone,
  and `#findbar`/`#sidebar-box` keep just the edge they share with the page.
- `doctor` warned "run `archway applet keyd grant`" on a machine where the
  grant worked: `/etc/polkit-1/rules.d` is `0750 root:polkitd`, so a normal user
  cannot `[[ -r ]]` the rule file. The check now probes the capability itself
  (`systemctl --no-ask-password start keyd` on the already-active unit, which is
  a no-op systemd still authorises) and says plainly when keyd is stopped.
- File uploads from a browser opened a picker where no shortcut seemed to work.
  Since Firefox 149 the XDG portal picker is the default: it opens as its own
  window, Hyprland tiled it behind the browser, and an unfocused dialog ignores
  Ctrl, Ctrl+click and double-click. The Firefox prefs now pin
  `widget.use-xdg-desktop-portal.file-picker = 0`, which keeps the in-process
  GTK3 picker this desktop themes and floats.
- `keyd` stayed in the `failed` state in `systemctl status` after every toggle:
  `keyd` exits with status 15 on SIGTERM, and `stop` left that recorded. The
  applet now runs `systemctl reset-failed keyd` after stopping (the grant covers
  it, `reset-failed` is part of `manage-units`).
- `Super+Alt+N` still asked for a password after `archway applet keyd grant`.
  The toggle ran `systemctl enable --now keyd`, and `enable` raises the
  `manage-unit-files` action, not the `manage-units` the rule authorises — the
  grant looked installed and did nothing. The toggle now only starts and stops
  the service (both `manage-units`), and enables/disables it only where it can
  authenticate, warning when it could not. `--dry-run` no longer enables the
  unit either.
- GTK file dialogs — the chooser Firefox opens for an upload — painted their
  places pane white while the rest of the window followed the palette. That pane
  is `placessidebar` (one word), a different node from Thunar's `.sidebar`, and
  nothing in the stylesheet matched it; the engine underneath was light because
  `gsettings` still said `Adwaita` and `gtk-application-prefer-dark-theme` was
  never set. The pane, the chooser's list and toolbar, dialogs and the backdrop
  state now all come from `palette.toml`, and the session prefers dark.
- Thunar and the chooser got the accessibility pass they were missing: place
  rows are 30px tall, keyboard focus draws the accent ring on the selected row
  instead of relying on colour, toolbar targets have a 24px floor and disabled
  controls keep the muted colour that still clears 4.5:1.
- The Wi-Fi pill printed the whole SSID, which pushed the right-hand icon group
  off the edge of a 1366px bar. `custom/net` replaces the native module with a
  12-character pill and a tooltip holding the full name, signal, address and
  gateway; low signal turns it `warning`.
- The failed-units pill opened a terminal that closed before it could be read:
  `on-click` was a bare `kitty -e systemctl --failed`, which printed the unit
  list and exited immediately. It now runs `--no-pager`, prints "Press Enter to
  close" and waits with `read -r _ </dev/tty` — the tty kitty gives the child,
  not waybar's stdin, which is not a usable terminal. The updates pill got the
  same closing line so both behave alike.
- The media pill no longer prints a running timer. `custom/media` renders
  `icon + artist — title` (14 characters, dimmed while paused) and the
  position/length moved into its tooltip, so hovering the music button shows
  "0:37 / 2:40". A clock on the bar changed the pill width every second and kept
  dragging the centred row. The clock line is skipped when a player reports no
  length (streams, some Firefox pages) instead of showing a meaningless `0:00`.
  `mpris` and `custom/nowplaying` are gone: the same custom module now stands in
  while nothing plays, which is what kept the slot from collapsing.
- Keybind parsing now undoes TOML's `\"` and `\\` escapes. Before, a command
  containing a double quote reached Hyprland with an extra backslash — the
  visible break was the theme picker, but any quoted argument would have hit it.
- Bar: the window title sits next to the workspaces instead of after a 15px zone
  break, and both the title and the media pills are shorter (`max-length` 11 and
  14, reserved widths 72px and 104px), so the right-hand status cluster starts
  further left without the row resizing on every window switch.
- The updates pill no longer dies with `==> ERROR: Cannot fetch updates` when
  clicked. `checkupdates` locks a shared sync-db directory, so the bar refresh
  and the click handler collided. Each invocation now gets a private
  `CHECKUPDATES_DB`, and the click runs `archway-bar updates --list`, which
  prints the pending packages (or says the system is current) in a floating
  terminal. A failed check reports "could not check updates" instead of a
  confident zero.
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
