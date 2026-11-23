# Contributing to Archway

Archway is a dotfiles framework, not a theme shop: a change has to be
reproducible, reversible and testable before it looks good. The full rules live
in [AGENTS.md](AGENTS.md); this page is the practical path through them.

## Before you write code

1. Read `AGENTS.md` §2 (non-negotiables) and §13 (code standards).
2. Open an issue for anything larger than a typo. Describe the failure, not the
   patch.
3. Check `git log` and `CHANGELOG.md` — the problem may already be known.

## Development environment

```bash
git clone https://github.com/grubberdubber/archway
cd archway
./bin/archway version            # the CLI runs straight from the checkout
./bin/archway install --dry-run  # never writes; shows the plan
```

Everything runs on Arch Linux. Testing in a container or VM is expected — the
owner's machine is production (AGENTS.md §2.1).

## Checks a change must pass

```bash
shellcheck -x bin/archway install.sh $(find lib applets scripts tests -name '*.sh')
shfmt -d -i 2 -ci -sr bin lib install.sh applets scripts tests
markdownlint-cli2                # 120 columns, see .markdownlint-cli2.yaml
./bin/archway theme validate android-mount
./bin/archway keys validate
bats tests/bats                  # or: just test
./tests/smoke.sh                 # end-to-end, throwaway HOME
```

`pre-commit install` wires the secret scan, shellcheck, shfmt, markdownlint and
typos into your commit. CI runs the same set plus a package-name check; a red
run is not a mergeable branch.

## Style

- **Shell:** `set -Eeuo pipefail`, `snake_case` functions, quoted expansions,
  `printf` over `echo`, arrays over word-splitting, no `eval`.
- **Comments:** explain *why*, never *what*. A comment that repeats the code is
  a comment that will rot.
- **Paths:** `$HOME`, XDG and chezmoi templates. No `/home/<user>`, no
  absolute paths in tracked files.
- **Themes:** one `palette.toml` per theme plus `theme.toml` metadata; templates
  are shared. A new app module belongs in `themes/_shared/<app>/`, not in a
  per-theme copy.
- **Lua/TOML/YAML/Markdown:** `stylua` (2 spaces, 120 columns), `taplo`,
  `yamllint`, `markdownlint-cli2`.

## Commits and pull requests

[Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`,
`docs:`, `refactor:`, `test:`, `chore:`. One logical change per commit, written
in English, imperative mood. Explain the *why* in the body when it is not
obvious; the diff already shows the *what*.

A pull request should state what changed, how it was tested (container, VM, real
hardware with consent), the risks, and how to revert it. Avoid mixing a refactor
with a behaviour change.

## Never

- Commit a secret, a token, a key, a `.env` or a browser profile.
- `curl ... | bash`, `sudo` for dotfiles, `rm -rf` without a guard.
- Overwrite an existing config without backup, manifest entry and consent.
- Copy or fork `grubberdubber/nvim-config` into this repository.
- Claim a feature works when it was only compiled or read.

## Licensing

Contributions are accepted under **GPL-3.0-or-later**, the license of the
repository. Keep SPDX headers, keep upstream copyright notices, and add yourself
to the credits of anything derived from someone else's work.

## Adding a theme

```bash
mkdir -p themes/my-theme
cp themes/ember/palette.toml themes/my-theme/palette.toml   # then edit
cp themes/ember/theme.toml  themes/my-theme/theme.toml
./bin/archway theme validate my-theme   # AA contrast, required keys
./bin/archway theme set my-theme
```

A theme is data plus templates. If a module needs a new key, add it to
`themes/_shared/` so every theme gets it; do not fork the shared CSS.
