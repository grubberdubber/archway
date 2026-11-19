#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# session-check — boot an Arch VM and walk the Hyprland session checklist.
#
# This is deliberately manual: a real session check needs a GPU-capable VM,
# a working login and human eyes on the theme, input and audio. The script
# validates the prerequisites, launches QEMU and prints the checklist; it never
# claims a pass it did not observe.
set -Eeuo pipefail

IMAGE=${ARCHWAY_VM_IMAGE:-}

usage() {
  cat << 'EOF'
session-check — Hyprland session check in a VM

Usage:
  ARCHWAY_VM_IMAGE=/path/to/arch.qcow2 session-check.sh [--run]

Without --run the script only checks prerequisites and prints the plan.
Requires: qemu-system-x86_64, an Arch image with Archway's profile installed,
and a virtio-gpu device (3D acceleration) so Hyprland can start.
EOF
}

die() {
  printf 'session-check: %s\n' "$1" >&2
  exit "${2:-1}"
}

checklist() {
  cat << 'EOF'

Manual checklist inside the VM (record the result in the release notes):
  [ ] login on the TTY and start the session through uwsm
  [ ] hyprctl version matches desktops/hyprland/compat.toml
  [ ] archway doctor: no critical issues
  [ ] Super+Return opens kitty; Super+Q closes it
  [ ] Super+1..9 switch workspaces; Super+Shift+1..9 move windows
  [ ] Super+Shift+S captures a region to the clipboard
  [ ] Super+V shows clipboard history
  [ ] Super+Escape locks; hyprlock asks for the password
  [ ] waybar and swaync start with the session and reload on theme change
  [ ] audio (pamixer/playerctl), Wi-Fi and Bluetooth work
  [ ] suspend/resume and a full reboot keep the session usable
  [ ] archway update --check and archway rollback (dry-run) behave

This script exits 0 when QEMU launched, not when the checklist passed.
EOF
}

run=0
while (($#)); do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --run) run=1 ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

command -v qemu-system-x86_64 > /dev/null 2>&1 || die "qemu-system-x86_64 is not installed" 3
[[ -n $IMAGE ]] || die "set ARCHWAY_VM_IMAGE to the qcow2 to boot" 2
[[ -r $IMAGE ]] || die "cannot read $IMAGE" 2

if ((! run)); then
  printf 'image : %s\n' "$IMAGE"
  printf 'plan  : qemu-system-x86_64 -enable-kvm -m 4G -cpu host -smp 4 \\\n'
  printf '          -device virtio-vga-gl -display gtk,gl=on -drive file=%s,if=virtio\n' "$IMAGE"
  checklist
  exit 0
fi

printf 'booting %s (close the window to end the check)\n' "$IMAGE"
qemu-system-x86_64 \
  -enable-kvm -m 4G -cpu host -smp 4 \
  -device virtio-vga-gl -display gtk,gl=on \
  -drive "file=$IMAGE,if=virtio"

checklist
