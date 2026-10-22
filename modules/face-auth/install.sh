#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SURFACE_SETUP_MODULE=face-auth
export SURFACE_SETUP_MODULE
SURFACE_SETUP_BACKUP_ID=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)-face-auth}
export SURFACE_SETUP_BACKUP_ID
repo_root=$(cd "$module_root/../.." && pwd)

usage() {
  cat <<'USAGE'
Usage: modules/face-auth/install.sh [face|sudo-face|polkit-face|plugin-ui]

  face       Configure Howdy, enroll a local model, and install lock-screen UI
  sudo-face  Optional explicit-consent terminal sudo authentication
  polkit-face Optional explicit-consent graphical Polkit authentication
  plugin-ui  Upgrade existing face plugin UI only
USAGE
}

action=${1:-face}
if [[ $# -gt 0 ]]; then shift; fi
case $action in
  face) [[ $# -eq 0 ]] || { usage >&2; exit 2; }; exec "$module_root/scripts/install-face.sh" ;;
  sudo-face) exec "$module_root/scripts/install-sudo-face.sh" "$@" ;;
  polkit-face) exec "$module_root/scripts/install-polkit-face.sh" "$@" ;;
  plugin-ui) exec "$module_root/scripts/install-plugin-ui.sh" "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
