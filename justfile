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
  ./bin/archway theme nvim-contract android-mount

# Regenerate the Hyprland binds + docs from keybinds/keybinds.toml.
keys:
  ./bin/archway keys generate

# Unit tests (requires bats).
test:
  bats tests/bats

# End-to-end suite with a throwaway HOME.
test-e2e:
  ./tests/smoke.sh

# Integration checks in a real Arch container. Mutating commands refuse root,
# so the suite runs as an unprivileged user inside the container.
test-container:
  docker run --rm -v "$PWD":/src:ro -w / archlinux:latest bash -lc '\
    cp -a /src /w && cd /w && \
    pacman -Syu --noconfirm --needed bash git jq shellcheck shfmt bats >/dev/null && \
    shellcheck -x bin/archway install.sh $$(find lib applets scripts tests -type f -name "*.sh") && \
    shfmt -d -i 2 -ci -sr bin lib install.sh applets tests && \
    ./bin/archway theme validate android-mount && \
    ./bin/archway keys check && \
    bats tests/bats && \
    useradd -m ci && chown -R ci:ci /w && \
    su ci -c "cd /w && HOME=/home/ci ./tests/smoke.sh"'

# Session test requires a VM: it is manual by design, never a silent no-op.
test-vm:
  ./tests/vm/session-check.sh

# Doctor on this checkout.
doctor:
  ./bin/archway doctor

# Release gate (AGENTS.md §14.3), minus the hardware steps.
release-check: lint test
  ./bin/archway keys check
  ./bin/archway theme validate android-mount
  ./bin/archway theme nvim-contract android-mount
  gitleaks dir . --no-banner --redact

# Full local CI approximation.
check: lint keys
  @git diff --exit-code docs/keybinds.md dotfiles/dot_config/hypr/conf.d/20-keybinds.conf || \
    { echo "generated files out of date: run 'just keys'"; exit 1; }
  bats tests/bats

# Print the install plan for this host; writes nothing.
plan:
  ./bin/archway install --dry-run
