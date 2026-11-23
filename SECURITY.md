# Security policy

Archway installs system packages, writes to `$HOME` and manages a compositor
session, so a bug here can cost someone their data. Reports are welcome and
handled with that in mind.

## Supported versions

| Version | Supported |
|---|---|
| `main` (edge) | fixes land here first |
| `v0.1.x` (stable, once tagged) | security fixes only |

Pre-alpha: there is no long-term support branch yet. If you run a tagged
release, upgrade to the latest tag before reporting.

## Reporting a vulnerability

**Do not open a public issue, and never paste a secret, key, token or personal
path into a report.**

- GitHub: <https://github.com/grubberdubber/archway/security/advisories/new>
  (private advisory, preferred)
- Email: the address on the owner's GitHub profile, subject `archway security`

Include: affected version/commit, distribution and session (X11/Wayland), the
smallest reproduction, and the impact you expect. If the report involves a
credential, rotate it first — a deleted commit does not un-leak a secret.

You can expect an acknowledgement within 72 hours and a first assessment within
a week. This is a single-maintainer project; timelines are honest, not
contractual.

## What is in scope

- The CLI (`bin/archway`, `lib/`) and `install.sh`
- Applets under `applets/`
- Theme generation (`lib/theme.sh`, `themes/`)
- Anything that writes outside the checkout: `$HOME`, `/etc`, systemd units,
  polkit rules
- Supply chain: pinned checksums, GitHub Actions, package manifests

Out of scope: vulnerabilities in Arch packages or upstream projects (report
those upstream — Archway only passes the report along), and issues that require
an already-compromised machine or root.

## How Archway handles secrets

- Nothing secret is committed; gitleaks runs in pre-commit and CI.
- `~/.config/gh/hosts.yml`, `.env`, key material, vault databases and browser
  profiles are git-ignored, and `uninstall` never touches them.
- State, backups and logs live under `~/.local/state/archway/`; logs redact
  values that look like credentials and backups are created with `umask 077`.
- `archway doctor` reports a leaked-looking value as a warning; it does not
  print it.

## Safe defaults worth knowing

- `archway install` is additive: existing files are backed up, recorded and
  never overwritten without consent (AGENTS.md §2.1).
- `archway` refuses to run as root, and `sudo` is only ever requested for
  packages and services.
- Theme and Neovim pin changes are validated before they are applied; Neovim
  failure rolls back its own pin without taking the desktop down.
