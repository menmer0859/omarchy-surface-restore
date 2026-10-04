#!/usr/bin/env bash

set -euo pipefail

SURFACE_SETUP_BACKUP_ROOT=${SURFACE_SETUP_BACKUP_ROOT:-/var/backups/omarchy-surface-restore}
SURFACE_SETUP_BACKUP_ID=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)}
export SURFACE_SETUP_BACKUP_ROOT SURFACE_SETUP_BACKUP_ID

info() { printf '==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_commands() {
  local command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command not found: $command_name"
  done
}

ask_yes_no() {
  local prompt=${1:-Continue?}
  local answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

backup_path() {
  local source_path=${1:?Usage: backup_path PATH}
  [[ -e "$source_path" || -L "$source_path" ]] || die "Cannot back up missing path: $source_path"

  local snapshot="$SURFACE_SETUP_BACKUP_ROOT/$SURFACE_SETUP_BACKUP_ID"
  local target="$snapshot/${source_path#/}"

  if [[ -e "$target" || -L "$target" ]]; then
    printf '%s\n' "$target"
    return 0
  fi

  if [[ -w "$SURFACE_SETUP_BACKUP_ROOT" || -w "$(dirname "$SURFACE_SETUP_BACKUP_ROOT")" ]]; then
    mkdir -p "$snapshot"
    cp -a --parents -- "$source_path" "$snapshot"
  else
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to create a protected system backup'
    sudo install -d -m 0700 "$snapshot"
    sudo cp -a --parents -- "$source_path" "$snapshot"
  fi

  printf '%s\n' "$target"
}

mark_new_path() {
  local new_path=${1:?Usage: mark_new_path PATH}
  local snapshot="$SURFACE_SETUP_BACKUP_ROOT/$SURFACE_SETUP_BACKUP_ID"
  if [[ -w "$SURFACE_SETUP_BACKUP_ROOT" || -w "$(dirname "$SURFACE_SETUP_BACKUP_ROOT")" ]]; then
    mkdir -p "$snapshot"
    printf '%s\n' "$new_path" >> "$snapshot/.created_paths"
  else
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to record a newly created system path'
    sudo install -d -m 0700 "$snapshot"
    printf '%s\n' "$new_path" | sudo tee -a "$snapshot/.created_paths" >/dev/null
  fi
  info "Recorded new path for restore: $new_path"
}

require_omarchy() {
  [[ -d /usr/share/omarchy ]] || die 'Omarchy files were not found under /usr/share/omarchy.'
  command -v omarchy-shell >/dev/null 2>&1 || die 'omarchy-shell is not available; run this on an Omarchy desktop.'
}

require_surface_hint() {
  local product=''
  local vendor=''
  [[ -r /sys/devices/virtual/dmi/id/product_name ]] && product=$(cat /sys/devices/virtual/dmi/id/product_name)
  [[ -r /sys/devices/virtual/dmi/id/sys_vendor ]] && vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor)

  if [[ "$vendor $product" != *Microsoft* && "$vendor $product" != *Surface* ]]; then
    warn "This machine did not identify itself as a Microsoft Surface ($vendor $product)."
    ask_yes_no 'Continue anyway?' || die 'Stopped before making changes.'
  fi
}

backup_and_report() {
  local item backup
  for item in "$@"; do
    [[ -e "$item" || -L "$item" ]] || continue
    backup=$(backup_path "$item")
    info "Backed up $item to $backup"
  done
}
