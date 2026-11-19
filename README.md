# Archway

A staff-grade dotfiles framework for Arch Linux: one command to install a
beautiful, fast, keyboard-first desktop; one command to keep it updated
forever without reinstalling or losing your own configuration.

**Status:** pre-alpha (`v0.1.0`, codename *Mount*). First physical target is a
friend's laptop, not a production machine. Archway never writes to `$HOME`
without a backup, a manifest entry and your explicit consent.

```bash
# dry-run first — nothing is written, you see the whole plan
./bin/archway install --dry-run

# then, when you agree with the plan
./bin/archway install --profile developer --wm bspwm --terminal kitty
```

## What you get

- **bspwm** + `sxhkd` + **polybar** + **rofi** + **dunst** + `picom` (X11, v0.1)
- **kitty** terminal, native modular **zsh** (no Oh-My-Zsh), `starship`, `tmux`
- **Neovim** from the pinned [`grubberdubber/nvim-config`](https://github.com/grubberdubber/nvim-config)
- The **Android Mount** theme: hand-written Material-You-inspired dark palette,
  WCAG AA checked, propagated to every enabled application
- **Android Mount applet**: mount/unmount MTP devices from Rofi, safely
- Single-source keybinds that generate `sxhkdrc` and the cheatsheet
- `archway doctor`, `archway update`, `archway rollback`

## Why updating does not mean re-cloning

Each machine keeps **one** checkout at `~/.local/share/archway/src`, with a
`~/.local/bin/archway` symlink into it. `archway update`:

1. refuses to run on a dirty tree,
2. `git fetch --tags` and fast-forwards,
3. snapshots/backs up managed files,
4. runs pending migrations,
5. `chezmoi apply` — which compares content and **only touches files that
   actually changed**,
6. runs `archway doctor` and rolls back automatically if a critical check fails.

That is the "scan for new files and replace only those" behaviour, with
`chezmoi` as the engine (ADR-001, ADR-009). No `git clone` per update.

## Requirements

Arch Linux x86_64, `bash >= 5.2`, `git`, `chezmoi`, `pacman`, a non-root user.
`gum`/`fzf` are optional (plain prompts are used when missing).

## Commands

| Command | Purpose |
|---|---|
| `archway install` | preflight, plan, backup, packages, dotfiles, Neovim, theme, doctor |
| `archway update` | fast-forward + backup + migrations + apply + doctor (+ rollback) |
| `archway rollback` | restore the last consistent backup |
| `archway doctor` | diagnose deps, theme, keybinds, Neovim pin, state |
| `archway theme` | `list`, `current`, `set`, `preview`, `validate`, `render` |
| `archway nvim` | `install`, `pin`, `status`, `doctor`, `rollback` |
| `archway keys` | `list`, `search`, `generate`, `validate`, `check` |
| `archway applet` | run a bundled applet (`android-mount`, `screenshot`, `power`, `theme-selector`) |
| `archway pkg` | `list`, `why`, `export`, `check` |
| `archway backup` / `restore` | manual backup and restore |
| `archway uninstall` | remove managed files, restore backups |
| `archway version` | version, commit, channel, host, profile, theme, Neovim pin |

Every command supports `--help`; mutating commands support `--dry-run` and
`--yes` (never implies `--force`). Exit codes: `0` ok, `1` error, `2` usage,
`3` preflight failed, `4` cancelled by user, `5` rollback executed.

## Safety model

- Never root; refuses to run with `EUID=0`.
- `~/.zshrc`, `~/.config/bspwm`, `~/.config/nvim` and friends are never
  overwritten silently: backup → manifest → consent, or explicit `--adopt`.
- Configs are additive. The zsh config lives in `~/.config/zsh` and is loaded
  with one line you add yourself.
- On a host listed in `production_hosts` (default: `arch`), `install` is forced
  to `--dry-run` unless `--apply-production` is passed.
- No secrets in the repository. `gitleaks` runs in CI and pre-commit.

## Layout

```text
bin/archway          CLI entrypoint            lib/       core logic
keybinds/            single source of truth    themes/    palette + templates
applets/             rofi applets              profiles/  minimal..full
packages/            verified manifests         dotfiles/  chezmoi source
deps/nvim-config.lock                           tests/     bats
docs/                keybinds, troubleshooting, uninstall
```

## Documentation

- [`docs/keybinds.md`](docs/keybinds.md) — generated cheatsheet
- [`docs/troubleshooting.md`](docs/troubleshooting.md)
- [`docs/uninstall.md`](docs/uninstall.md)
- [`AGENTS.md`](AGENTS.md) — engineering constitution (Spanish)
- [`CHANGELOG.md`](CHANGELOG.md), [`CREDITS.md`](CREDITS.md)

## License

GPL-3.0-or-later. See [`LICENSE`](LICENSE).

---

## Español

Archway instala un escritorio bspwm keyboard-first en Arch Linux con un solo
comando, lo actualiza sin reinstalar (`archway update`) y lo revierte
(`archway rollback`). Todo cambio en tu `$HOME` pasa por backup, manifiesto y
consentimiento explícito. La primera prueba física se hace en una laptop
ajena, nunca en producción.
