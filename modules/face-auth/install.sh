#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SURFACE_SETUP_MODULE=face-auth
export SURFACE_SETUP_MODULE
SURFACE_SETUP_BACKUP_ID=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)-face-auth}
export SURFACE_SETUP_BACKUP_ID
repo_root=$(cd "$module_root/../.." && pwd)
source "$repo_root/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: modules/face-auth/install.sh [face [--all|--lock --sudo --polkit]|sudo-face|polkit-face|plugin-ui]

  face       Guided single-run setup for lock, sudo, and graphical Polkit
  sudo-face  Optional explicit-consent terminal sudo authentication
  polkit-face Optional explicit-consent graphical Polkit authentication
  plugin-ui  Upgrade existing face plugin UI only
USAGE
}

action=${1:-face}
if [[ $# -gt 0 ]]; then shift; fi
case $action in
  face)
    if [[ ${1:-} == --all ]]; then
      [[ $# -eq 1 ]] || { usage >&2; exit 2; }
      exec "$module_root/scripts/run-face-setup.sh" --lock --sudo --polkit
    fi
    exec "$module_root/scripts/run-face-setup.sh" "$@"
    ;;
  sudo-face)
    [[ $# -eq 0 ]] || { usage >&2; exit 2; }
    begin_face_transaction sudo
    bash "$module_root/scripts/install-sudo-face.sh"
    capture_face_transaction
    set_face_transaction_status installed
    ;;
  polkit-face)
    [[ $# -eq 0 ]] || { usage >&2; exit 2; }
    begin_face_transaction polkit
    bash "$module_root/scripts/install-polkit-face.sh"
    capture_face_transaction
    set_face_transaction_status installed
    ;;
  plugin-ui) exec "$module_root/scripts/install-plugin-ui.sh" "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
