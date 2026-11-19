# Troubleshooting

Start with `archway doctor`. It reports dependencies, theme validity, keybind
integrity, the Neovim pin and state in under five seconds, and `--json` gives
the same data to a script.

Logs: `~/.local/state/archway/logs/<timestamp>-<pid>.log`
Backups: `~/.local/state/archway/backups/<timestamp>/`

## Install refuses to run

| Message | Cause | Fix |
|---|---|---|
| `must not run as root` | `sudo archway …` | run as your user; sudo is requested only for packages |
| `chezmoi is required` | engine missing | `sudo pacman -S chezmoi` |
| `this is a production host` | hostname is in `production_hosts` | review the plan, then pass `--apply-production` |
| `unknown profile` | typo | `archway install --help` lists the four profiles |
| `less than 10 GB free` | disk space check | free space, or accept the warning knowingly |

## Dotfiles were not applied / were applied over my file

`chezmoi` is the engine. `archway install --dry-run` and `archway update --dry-run`
show the change list first. Every modified path is copied to
`~/.local/state/archway/backups/<timestamp>/` before it changes, and the path is
written to `managed.tsv`.

- Inspect what chezmoi thinks: `chezmoi --source ~/.local/share/archway/src/dotfiles status`
- Undo everything from the last run: `archway rollback`
- Adopt your versions instead: keep them, then run `archway install --adopt`
  (it still backs them up, and it will not touch files it does not manage).

## Theme looks wrong in one application

`archway theme set android-mount` renders every module into
`~/.config/archway/theme.d/` and reloads running components.

- kitty needs `allow_remote_control socket-only` (already in the shipped config)
  and a `KITTY_LISTEN_ON` socket to hot-reload; otherwise open a new window.
- polybar and rofi read the files on restart: `polybar-msg cmd restart`.
- dunst and bat get native copies (`dunst/dunstrc.d/90-android-mount.conf`,
  `bat/themes/android-mount.tmTheme`) because they cannot include arbitrary paths.
- Neovim applies the theme on its next start, never by reloading a session with
  unsaved buffers.

Validate the palette itself: `archway theme validate android-mount`.

## Neovim does not get the theme

Archway writes **only** `~/.config/nvim/lua/archway.lua` and refuses to touch
tracked files. If the checkout does not ignore that path, `theme set` reports a
critical failure and exits `1`. That is intentional: ask upstream for the hook
(see `AGENTS.md` §9.5) or update the pin.

## `archway update` says the checkout has local changes

Your edits are your work; Archway never resets them. Run
`git -C ~/.local/share/archway/src status`, commit or stash, then retry. If you
diverged deliberately, `archway pin <version>` keeps this host on a known
version and `archway update --check` still reports newer releases.

## Neovim pin is a placeholder

`deps/nvim-config.lock` ships unpinned so no fake commit can be baked in. Run:

```bash
archway nvim pin v0.1.0     # resolves commit + tarball SHA256
archway nvim install
```

Until then the desktop installs fine; only Neovim is skipped.

## Keybind does nothing

- `archway keys validate` catches duplicates, empty commands and reserved chords.
- `super + /` opens the generated cheatsheet.
- Applet bindings go through `archway applet <name>`, so they work from any
  checkout as long as `archway` is on `PATH` (`~/.local/bin/archway`).
- sxhkd must be running: `pgrep -x sxhkd`. `bspc wm -r` reloads the window
  manager and restarts it.

## Android device is not listed

1. Unlock the phone and choose **File transfer (MTP)** in the USB notification.
2. `archway applet android-mount list` — the index is the number on the left.
3. `lsusb` should show the device; a charge-only cable is a common cause.
4. `simple-mtpfs` and `fuse2` must be installed.
5. To unmount safely: `archway applet android-mount unmount <index>`; the applet
   refuses paths outside `~/Android_Mount`.

## Audio, network, Bluetooth

`pipewire`, `wireplumber`, `networkmanager` and `bluez` are part of the desktop
manifest. Enable the services you need:

```bash
sudo systemctl enable --now NetworkManager bluetooth
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

## NVIDIA, Secure Boot, LUKS, dual boot

Archway detects and warns but does not guess. For NVIDIA install
`nvidia`/`nvidia-dkms` yourself and verify the session before relying on it. For
Secure Boot use `sbctl`; for LUKS enrolment use `systemd-cryptenroll`. Archway
never repartitions, never removes Windows and never changes your bootloader.

## Getting back to a known state

```bash
archway backup list       # what is available
archway rollback          # newest backup, asks first, exit code 5 when done
archway restore <id>      # a specific backup
```

If rollback itself fails, the backups are plain directories: copy
`backups/<id>/files/<original path>` back by hand and read the log.
