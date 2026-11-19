# Migrations

Numbered, idempotent shell scripts executed **exactly once** by `archway update`
(and by `archway install` on a machine that has never run them).

## Rules

1. Name the file `NNNN-short-description.sh` (`0001-move-zsh-config.sh`).
2. Use `#!/usr/bin/env bash` and `set -Eeuo pipefail`.
3. Be idempotent: running it twice must be harmless.
4. Back up anything you modify under `$HOME` before modifying it.
5. Never delete user data; move it aside and tell the user where it went.
6. Exit non-zero on failure. Archway stops, restores the pre-update backup and
   does not continue with later migrations.
7. Record every compatibility break in `CHANGELOG.md`; bump the version
   according to SemVer.

## Stamps

A successful run writes `~/.local/state/archway/migrations/<name>.done`.
Deleting a stamp re-runs that migration on the next update — do that only when
you know it is safe.

## Testing

Migrations are covered by `tests/bats` where they carry real logic, and always
by a container run of `archway update --dry-run` in CI.
