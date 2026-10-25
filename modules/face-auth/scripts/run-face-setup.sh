#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
status_script="$module_root/scripts/face-setup-status.py"
selected_lock=false
selected_sudo=false
selected_polkit=false
repo_root=$(cd "$module_root/../.." && pwd)
source "$repo_root/lib/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage: run-face-setup.sh [--lock] [--sudo] [--polkit]

Select the integrations in this single guided install. Howdy is installed and
enrolled once when needed; password authentication remains available.
USAGE
}

while (($#)); do
  case "$1" in
    --lock) selected_lock=true ;;
    --sudo) selected_sudo=true ;;
    --polkit) selected_polkit=true ;;
    -h|--help) usage >&1; exit 0 ;;
    *) usage; exit 2 ;;
  esac
  shift
done

if [[ "$selected_lock" != true && "$selected_sudo" != true && "$selected_polkit" != true ]]; then
  printf 'Choose face-authentication integrations to install in this run.\n'
  ask_yes_no 'Install lock-screen face authentication?' && selected_lock=true || true
  ask_yes_no 'Install consent-gated terminal sudo face authentication?' && selected_sudo=true || true
  ask_yes_no 'Install consent-gated graphical Polkit face authentication?' && selected_polkit=true || true
fi

if [[ "$selected_lock" != true && "$selected_sudo" != true && "$selected_polkit" != true ]]; then
  usage
  exit 2
fi

read_status() {
  python3 "$status_script" --json
}

status_true() {
  local json=$1 key_path=$2
  python3 - "$json" "$key_path" <<'PY'
import json
import sys

try:
    value = json.loads(sys.argv[1])
    for key in sys.argv[2].split("."):
        value = value[key]
except (KeyError, TypeError, json.JSONDecodeError):
    raise SystemExit(1)
raise SystemExit(0 if value is True else 1)
PY
}

status_json=$(read_status) || { echo 'Could not inspect face-authentication readiness.' >&2; exit 1; }
if ! status_true "$status_json" camera.available || ! status_true "$status_json" camera.accessible; then
  echo 'No accessible stable camera path is available. Check the IR camera and user permissions before configuring face authentication.' >&2
  exit 1
fi

integrations=()
[[ "$selected_lock" == true ]] && integrations+=(lock)
[[ "$selected_sudo" == true ]] && integrations+=(sudo)
[[ "$selected_polkit" == true ]] && integrations+=(polkit)
begin_face_transaction "${integrations[@]}"

if ! status_true "$status_json" howdy.ready; then
  bash "$module_root/scripts/install-howdy-base.sh"
  status_json=$(read_status) || { echo 'Could not verify the Howdy installation.' >&2; exit 1; }
  status_true "$status_json" howdy.ready || { echo 'Howdy and a local face model are not ready; selected authentication services were not installed.' >&2; exit 1; }
fi

if [[ "$selected_lock" == true ]]; then
  bash "$module_root/scripts/install-lock-face.sh"
fi
if [[ "$selected_sudo" == true ]]; then
  bash "$module_root/scripts/install-sudo-face.sh"
fi
if [[ "$selected_polkit" == true ]]; then
  bash "$module_root/scripts/install-polkit-face.sh"
fi

status_json=$(read_status) || { echo 'Could not verify the selected authentication integrations.' >&2; exit 1; }
if [[ "$selected_lock" == true ]]; then
  status_true "$status_json" lock.passwordFallback || { echo 'Lock password fallback is not ready; the face lock was not marked complete.' >&2; exit 1; }
  status_true "$status_json" lock.ready || { echo 'Lock face authentication did not pass the final readiness check.' >&2; exit 1; }
fi
if [[ "$selected_sudo" == true ]]; then
  status_true "$status_json" sudo.ready || { echo 'Terminal sudo face authentication did not pass the final readiness check.' >&2; exit 1; }
fi
if [[ "$selected_polkit" == true ]]; then
  status_true "$status_json" polkit.ready || { echo 'Graphical Polkit face authentication did not pass the final readiness check.' >&2; exit 1; }
fi

printf 'Selected face authentication integrations passed the final readiness check. Password fallback remains available.\n'
capture_face_transaction
set_face_transaction_status installed
