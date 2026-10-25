#!/usr/bin/env bash

set -euo pipefail

if [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]]; then
  SURFACE_SETUP_BACKUP_ROOT=${SURFACE_SETUP_BACKUP_ROOT:-/tmp/omarchy-surface-restore-test-backups}
  [[ "$SURFACE_SETUP_BACKUP_ROOT" == /tmp/* ]] || { printf 'Isolated test backup roots must be inside /tmp.\n' >&2; exit 1; }
else
  SURFACE_SETUP_BACKUP_ROOT=/var/backups/omarchy-surface-restore
fi
SURFACE_SETUP_BACKUP_ID=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)}
export SURFACE_SETUP_BACKUP_ROOT SURFACE_SETUP_BACKUP_ID SURFACE_SETUP_MODULE

record_snapshot_module() {
  local snapshot="$SURFACE_SETUP_BACKUP_ROOT/$SURFACE_SETUP_BACKUP_ID"
  [[ -n ${SURFACE_SETUP_MODULE:-} ]] || return 0
  if [[ -w "$SURFACE_SETUP_BACKUP_ROOT" || -w "$(dirname "$SURFACE_SETUP_BACKUP_ROOT")" ]]; then
    mkdir -p "$snapshot"
    printf '%s\n' "$SURFACE_SETUP_MODULE" > "$snapshot/.surface_module"
  else
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to label a module backup'
    sudo install -d -m 0700 "$snapshot"
    printf '%s\n' "$SURFACE_SETUP_MODULE" | sudo tee "$snapshot/.surface_module" >/dev/null
    sudo chmod 0600 "$snapshot/.surface_module"
  fi
}

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

  record_snapshot_module

  if [[ -e "$target" || -L "$target" ]]; then
    record_snapshot_path .backed_up_paths "$source_path"
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

  record_snapshot_path .backed_up_paths "$source_path"
  printf '%s\n' "$target"
}

record_snapshot_path() {
  local record_name=${1:?Usage: record_snapshot_path RECORD PATH}
  local path=${2:?Usage: record_snapshot_path RECORD PATH}
  local snapshot="$SURFACE_SETUP_BACKUP_ROOT/$SURFACE_SETUP_BACKUP_ID"
  local record="$snapshot/$record_name"
  [[ "$path" == /* && "$path" != / && "$path" != *$'\n'* ]] \
    || die "Refusing to record an unsafe snapshot path: $path"

  if [[ -w "$SURFACE_SETUP_BACKUP_ROOT" || -w "$(dirname "$SURFACE_SETUP_BACKUP_ROOT")" ]]; then
    mkdir -p "$snapshot"
    touch "$record"
    grep -Fxq -- "$path" "$record" || printf '%s\n' "$path" >> "$record"
  else
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to record a system snapshot path'
    sudo install -d -m 0700 "$snapshot"
    if ! sudo grep -Fxq -- "$path" "$record" 2>/dev/null; then
      printf '%s\n' "$path" | sudo tee -a "$record" >/dev/null
      sudo chmod 0600 "$record"
    fi
  fi
}

mark_new_path() {
  local new_path=${1:?Usage: mark_new_path PATH}
  local snapshot="$SURFACE_SETUP_BACKUP_ROOT/$SURFACE_SETUP_BACKUP_ID"
  record_snapshot_module
  if [[ -w "$SURFACE_SETUP_BACKUP_ROOT" || -w "$(dirname "$SURFACE_SETUP_BACKUP_ROOT")" ]]; then
    mkdir -p "$snapshot"
    touch "$snapshot/.created_paths"
    grep -Fxq -- "$new_path" "$snapshot/.created_paths" || printf '%s\n' "$new_path" >> "$snapshot/.created_paths"
  else
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to record a newly created system path'
    sudo install -d -m 0700 "$snapshot"
    if ! sudo grep -Fxq -- "$new_path" "$snapshot/.created_paths" 2>/dev/null; then
      printf '%s\n' "$new_path" | sudo tee -a "$snapshot/.created_paths" >/dev/null
      sudo chmod 0600 "$snapshot/.created_paths"
    fi
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

# Required by the bilingual plugin; stop before mutation on older shells.
require_face_ui_api() {
  [[ -r /usr/share/omarchy/shell/Commons/Translations.qml ]] || die 'This plugin UI requires Omarchy Commons.Translations. Update Omarchy before installing the UI.'
}

# Back up the old plugin directory, then record every newly introduced path so
# restore removes new catalogs/components before restoring the earlier version.
install_face_ui_resources() {
  local kind=$1 target=$2 relative
  python3 "$root/modules/face-auth/scripts/deploy-face-ui.py" "$kind" "$target" --check
  while IFS= read -r relative; do
    [[ -e "$target/$relative" ]] || mark_new_path "$target/$relative"
  done < <(python3 "$root/modules/face-auth/scripts/deploy-face-ui.py" "$kind" "$target" --list)
  python3 "$root/modules/face-auth/scripts/deploy-face-ui.py" "$kind" "$target"
}

# Create one protected face-auth ledger before the first system mutation. A
# subsequent invocation reuses its ID and original package baseline.
begin_face_transaction() {
  local face_root
  local state_file=/var/lib/omarchy-surface-restore/face-auth.json
  [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]] && state_file=${SURFACE_SETUP_FACE_STATE_FILE:-$state_file}
  face_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  local state_script="$face_root/modules/face-auth/scripts/face-install-state.py"
  local integration backup_id package
  local -a arguments=()
  (($# > 0)) || die 'At least one face-auth integration must be selected.'
  require_commands pacman sudo python3
  backup_id=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)-face-auth}
  arguments=(--state-file "$state_file" begin --user "${USER:?USER is required}" --backup-id "$backup_id")
  for integration in "$@"; do arguments+=(--integration "$integration"); done
  for package in howdy-git python-dlib-git; do
    if pacman -Qq "$package" >/dev/null 2>&1; then arguments+=(--package-present "$package"); fi
  done
  SURFACE_SETUP_BACKUP_ID=$(sudo python3 "$state_script" "${arguments[@]}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])') \
    || die 'Could not create or read the protected face-auth install record.'
  export SURFACE_SETUP_BACKUP_ID SURFACE_SETUP_FACE_STATE_FILE="$state_file"
}

set_face_transaction_status() {
  local status=${1:?Usage: set_face_transaction_status STATUS}
  local face_root
  local state_file=/var/lib/omarchy-surface-restore/face-auth.json
  [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]] && state_file=${SURFACE_SETUP_FACE_STATE_FILE:-$state_file}
  face_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  sudo python3 "$face_root/modules/face-auth/scripts/face-install-state.py" --state-file "$state_file" status "$status" >/dev/null
}

capture_face_transaction() {
  local face_root state_file backup_root target_root=/
  face_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  state_file=/var/lib/omarchy-surface-restore/face-auth.json
  backup_root=/var/backups/omarchy-surface-restore
  if [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]]; then
    state_file=${SURFACE_SETUP_FACE_STATE_FILE:-$state_file}
    backup_root=${SURFACE_SETUP_BACKUP_ROOT:-$backup_root}
    target_root=${SURFACE_SETUP_TARGET_ROOT:-$target_root}
  fi
  sudo python3 "$face_root/modules/face-auth/scripts/face-install-state.py" --state-file "$state_file" \
    capture --backup-root "$backup_root" --target-root "$target_root" >/dev/null
}
