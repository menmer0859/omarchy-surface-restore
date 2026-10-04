#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/common.sh"
require_commands curl gpg pacman sudo
require_surface_hint

key_fingerprint=87DEFA4AB94A99A4C8C3112556C464BAAC421453
key_url=https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc
repo_block=$'\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\n'

if ! grep -q '^\[linux-surface\]$' /etc/pacman.conf; then
  backup_and_report /etc/pacman.conf
fi

key_file=$(mktemp)
trap 'rm -f "$key_file"' EXIT
curl --fail --location --silent --show-error "$key_url" --output "$key_file"
found_fingerprint=$(gpg --show-keys --with-colons "$key_file" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')
[[ "$found_fingerprint" == "$key_fingerprint" ]] || die "linux-surface signing-key fingerprint mismatch: $found_fingerprint"

printf 'This will add the official linux-surface repository and install its kernel, headers, and iptsd.\n'
printf 'The existing Omarchy kernel will remain installed. pacman -Syu may update other system packages.\n'
ask_yes_no 'Proceed?' || die 'Stopped before making changes.'

sudo -v
sudo pacman-key --add "$key_file"
sudo pacman-key --lsign-key "$key_fingerprint"
if ! grep -q '^\[linux-surface\]$' /etc/pacman.conf; then
  printf '%s' "$repo_block" | sudo tee -a /etc/pacman.conf >/dev/null
fi
sudo pacman -Syu --needed linux-surface linux-surface-headers iptsd

info 'Touch support packages are installed.'
printf 'Installed packages:\n'
pacman -Q linux-surface linux-surface-headers iptsd
printf '\nReboot, select the linux-surface entry in Limine if needed, then verify with:\n'
printf '  uname -r\n  systemctl status iptsd.service\n'
printf 'The kernel name should include "surface". The Omarchy kernel remains available as a fallback.\n'
