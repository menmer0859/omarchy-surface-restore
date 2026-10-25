#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SURFACE_SETUP_MODULE=face-auth
export SURFACE_SETUP_MODULE
SURFACE_SETUP_BACKUP_ID=${SURFACE_SETUP_BACKUP_ID:-$(date +%Y%m%d-%H%M%S)-face-auth-$BASHPID}
export SURFACE_SETUP_BACKUP_ID
root=$(cd "$module_root/../.." && pwd)
source "$root/lib/common.sh"
require_omarchy
require_face_ui_api
require_commands install python3 omarchy omarchy-shell jq

pam_file=/etc/pam.d/omarchy-lock-face
[[ -s "$pam_file" ]] || die "Face PAM service is missing: $pam_file"
[[ -s /etc/howdy/models/${USER}.dat ]] || die "Howdy model is missing for $USER; enroll with: sudo howdy -U $USER add"

plugin_root="$HOME/.config/omarchy/plugins/surface.lock"
plugins_root="$HOME/.config/omarchy/plugins"
python3 "$module_root/scripts/deploy-face-ui.py" lock "$plugin_root" --check
if ! python3 "$module_root/scripts/check-lock-plugin-clones.py" "$plugins_root" "$plugin_root"; then
  die "Another Omarchy lock clone is installed. Disable it before installing this lock plugin."
fi

if [[ -e "$plugin_root" ]]; then
  backup_and_report "$plugin_root"
  [[ -e "$plugin_root/FaceAttemptPolicy.js" ]] || mark_new_path "$plugin_root/FaceAttemptPolicy.js"
else
  mark_new_path "$plugin_root"
  install -d -m 0755 "$plugin_root"
  mark_new_path "$plugin_root/manifest.json"
  mark_new_path "$plugin_root/Service.qml"
  mark_new_path "$plugin_root/LockView.qml"
  mark_new_path "$plugin_root/FaceAttemptPolicy.js"
fi

install -d -m 0755 "$plugin_root"
install -m 0644 "$module_root/assets/omarchy-lock/manifest.json" "$plugin_root/manifest.json"
install_face_ui_resources lock "$plugin_root"
shell_config="$HOME/.config/omarchy/shell.json"
if [[ -e "$shell_config" ]]; then backup_and_report "$shell_config"; else mark_new_path "$shell_config"; fi
enable_face_plugin surface.lock

info "Installed the bilingual face lock plugin at $plugin_root"
printf 'The shell plugin is enabled. Reload with: omarchy restart shell\n'
