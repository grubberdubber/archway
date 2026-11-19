# Changelog

All notable changes to Archway are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
