# Tools and file manager

Every config below lives in `dotfiles/dot_config/` and lands in
`~/.config/<app>/` through chezmoi. Colours come from the theme whenever the app
can read a generated file; the rest are static and documented as such.

## Terminal and shell

| What | Where | Notes |
|---|---|---|
| `less` | `zsh/conf.d/00-env.zsh` | `-R -F -X -i -M`; `LESSHISTFILE=-` so no keystroke log is written |
| `man` | `zsh/conf.d/00-env.zsh` | `MANPAGER` pipes through `col -bx` into `bat --language=man`, with `MANROFFOPT=-c`; falls back to `less` when bat is absent |
| `rg` | `~/.config/ripgrep/config` | smart-case, hidden files, build/cache excludes, palette colours |
| `zoxide` | `zsh/conf.d/30-tools.zsh` | `cd` is replaced only when zoxide exists |
| `fzf` | `zsh/conf.d/30-tools.zsh` | theme file sourced before `fzf --zsh` |
| `direnv`, `mise` | `30-tools.zsh` / `~/.config/mise/config.toml` | per-directory versions; nothing pinned globally |
| `lazygit` | `~/.config/lazygit/config.yml` + `theme.d/lazygit-theme.yml` | merged through `LG_CONFIG_FILE`, so a theme switch repaints it |
| `delta` | `~/.config/git/config` | side-by-side off (1366px), line numbers, palette colours, `zdiff3` merges |
| `tealdeer` | `~/.config/tealdeer/config.toml` | compact pages, weekly cache update |
| `fastfetch` | `~/.config/fastfetch/config.jsonc` | no logo, two columns, no slow modules |
| `ssh` | `~/.config/archway/ssh_config` | included from `~/.ssh/config`; keys and hosts stay in `~/.ssh` |

## Viewers

| App | Config | Notes |
|---|---|---|
| `zathura` | `~/.config/zathura/zathurarc` | includes `theme.d/zathura-theme`; vim keys, `Ctrl+R` recolour, page-width fit |
| `mpv` | `~/.config/mpv/{mpv.conf,input.conf}` | `vo=gpu`, `hwdec=auto-safe`, borderless, remembers position, vim seek keys, OSD from `theme.d/mpv-theme.conf` |
| `imv` | `~/.config/imv/config` | nearest-neighbour scaling, fit-on-open, vim motions |

Themes render `zathura-theme`, `mpv-theme.conf` and `lazygit-theme.yml`; a theme
without those modules inherits them from `themes/_shared/`.

## Gaming mode

`Super+Alt+G`, the rocket pill in the bar, or `archway applet gaming on|off`.
It sets the `performance` power profile, turns on do-not-disturb and pauses
`hypridle` (SIGSTOP, so the previous state comes back). `off` restores the
profile and DND value saved when it was enabled.

It is a **session** state, not a preference: the state file records the kernel
boot id, and anything stamped with a different boot is undone by
`archway applet gaming reconcile`, which Hyprland runs at session start and
`gaming status` also runs. Without that, a shutdown while the mode was on left
`power-profiles-daemon` remembering `performance` (it persists its profile in
`/var/lib/power-profiles-daemon/state.ini`) and the next login looked like
gaming mode had switched itself on. If the leftover is only the profile, set it
back with `powerprofilesctl set balanced`.

## Colour picker

`Super+Alt+C`, or the eyedropper pill in the bar.

```bash
archway applet color-picker            # pick, copy, notify
archway applet color-picker --no-copy  # pick and print only
archway applet color-picker --json
archway applet color-picker --dry-run  # say which backend would run
```

`hyprpicker` is the backend: the cursor becomes a zoom lens so the pixel under
it is visible before you commit, and `-s 6` keeps that lens readable on a
1366-wide panel. It ships in `extra`; `archway install` pulls it in, and on an
existing machine it is one package:

```bash
sudo pacman -S hyprpicker
```

Without it the applet falls back to `slurp -p` (a precise crosshair) plus a 1x1
`grim` grab: the pixel is still exact, but there is no lens. `--dry-run` says
which one you would get (`lens: zoom` or `lens: none`).

The colour is copied **once**, by the applet, rather than letting hyprpicker
copy and then copying again — two clipboard writes per pick show up twice in
`cliphist`. The notification carries the hex, the RGB triple and a swatch image
of the colour, so what was copied is on screen, not just in the clipboard.

Exit codes follow the CLI contract: `0` copied, `1` backend failure, `2` bad
usage, `4` cancelled (Esc or right click).

## Thunar

`~/.config/Thunar/thunar.xml` is written to be explicit rather than clever:

- single-click off, folders first, ISO dates, details view with the same column
  order everywhere;
- tabs always visible, `Ctrl+Page_Up/Down` and middle-click both usable,
  new windows open as tabs;
- client-side decorations off, so Hyprland draws the (square) frame and the
  GTK stylesheet owns the colours;
- thumbnails local-only with a 64 MB cap, preview pane off on a 768px screen;
- recursive search on, case-sensitive off, `Ctrl+scroll` zooms.

`uca.xml` adds: *Open Terminal Here*, *Open in Yazi*, *Edit with Neovim*,
*Copy Path*, *Extract Here* (bsdtar), *View Image* (imv), *Play with mpv* and
*Read in zathura*. Every command quotes `%f`, so paths with spaces stay one
argument.

Selection is GTK's: `Ctrl+click` toggles, `Shift+click` extends. The same
modifiers work in the file chooser a browser opens, once the picker is the GTK
one — see [firefox.md](firefox.md).

## Idle, lock and power

- `hypridle.conf`: screen off at 2 min, warning notification at 9 min, lock at
  9 min, suspend at 20 min. Lock before suspend so a resume never shows the
  last screen.
- `hyprlock.conf`: `source`s the generated theme, adds the user, a hint line and
  PAM login auth; the clock and colours come from the theme.
- `power-profiles-daemon` is enabled by the installer and shown in the bar.
- PipeWire + WirePlumber run as user services; EasyEffects presets are user data
  (`~/.config/easyeffects`) and are never shipped in the repo.
