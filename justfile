# Archway — developer tasks. Run `just` to list.
set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

# Static checks that are available locally.
lint:
  shellcheck -x bin/archway install.sh $(find lib applets scripts tests -type f -name '*.sh')
  shfmt -d -i 2 -ci -sr bin lib install.sh applets tests

fmt:
  shfmt -w -i 2 -ci -sr bin lib install.sh applets scripts tests

# Render every Android Mount artifact into a scratch dir (no $HOME writes).
theme:
  ./bin/archway theme render android-mount --to /tmp/archway-theme
  ./bin/archway theme validate android-mount

# Regenerate sxhkdrc + docs from keybinds/keybinds.toml.
keys:
  ./bin/archway keys generate

# Tests (requires bats).
test:
  bats tests/bats

# Full local CI approximation.
check: lint keys
  @git diff --exit-code docs/keybinds.md dotfiles/dot_config/sxhkd/sxhkdrc || \
    { echo "generated files out of date: run 'just keys'"; exit 1; }
  bats tests/bats

# Print the install plan for this host; writes nothing.
plan:
  ./bin/archway install --dry-run
