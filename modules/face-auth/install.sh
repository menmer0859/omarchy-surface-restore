#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SURFACE_SETUP_MODULE=face-auth
export SURFACE_SETUP_MODULE
SURFACE_SETUP_BACKUP_ID=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)-face-auth-$BASHPID}
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
  plugin-ui)
    [[ $# -eq 0 || ( $# -eq 1 && $1 == --check ) ]] || { usage >&2; exit 2; }
    if [[ ${1:-} == --check ]]; then exec "$module_root/scripts/install-plugin-ui.sh" "$@"; fi
    state_file=/var/lib/omarchy-surface-restore/face-auth.json
    [[ ${SURFACE_SETUP_TESTING:-0} != 1 ]] || state_file=${SURFACE_SETUP_FACE_STATE_FILE:-$state_file}
    require_commands sudo python3
    if sudo test -e "$state_file"; then
      state_json=$(sudo python3 "$module_root/scripts/face-install-state.py" --state-file "$state_file" show)
      state_status=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' <<<"$state_json")
      [[ $state_status == installed ]] || die 'Complete or remove the current face-auth transaction before upgrading its UI.'
      mapfile -t integrations < <(python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["integrations"]))' <<<"$state_json")
      begin_face_transaction "${integrations[@]}"
      bash "$module_root/scripts/install-plugin-ui.sh"
      capture_face_transaction
      set_face_transaction_status installed
    else
      exec "$module_root/scripts/install-plugin-ui.sh"
    fi
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
