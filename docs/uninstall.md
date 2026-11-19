# Uninstalling Archway

Archway removes **only what it manages**. Your files, your backups and your
packages stay put unless you explicitly ask otherwise.

## 1. Preview

```bash
archway uninstall --dry-run
```

This lists every path in `~/.local/state/archway/managed.tsv` and marks whether
it existed before Archway (kept) or was created by Archway (removed).

## 2. Remove managed files

```bash
archway uninstall --restore
```

`--restore` first restores the most recent backup over managed paths, then
removes paths the backup manifest proves did not exist before. You must type the
hostname to confirm; there is no `--force`.

## 3. Optionally delete state

```bash
archway uninstall --purge
```

Removes `~/.local/state/archway` (logs, backups, manifests) and
`~/.config/archway` (theme choice and generated fragments). Everything else is
untouched.

## 4. Packages

Packages are never removed automatically. Export what you had, then decide:

```bash
archway pkg export ~/archway-packages
pacman -Qqen > /tmp/official.txt
paru -Qqem > /tmp/aur.txt
# review before removing anything
sudo pacman -Rns $(comm -23 <(sort /tmp/official.txt) <(sort /tmp/keep.txt))
```

## 5. Shell

If you let the installer add the loader to `~/.zshenv`, remove the two marked
lines (`# archway-zsh: …` and the `ZDOTDIR` export). Your shell keeps working;
it just stops loading `~/.config/zsh`.

## 6. Neovim

- If Archway **replaced** an existing `~/.config/nvim`, the original is in
  `~/.local/state/archway/backups/<timestamp>/moved/nvim`; restore it.
- If Archway **adopted** an existing `grubberdubber/nvim-config` checkout, it is
  left exactly where it is.
- `uninstall` never deletes `~/.config/nvim` without consent.

## What is never touched

`~/.ssh`, `~/.gnupg`, `~/.config/gh`, browser profiles, password databases,
documents, photos, virtual machines, and any file outside the managed manifest.
