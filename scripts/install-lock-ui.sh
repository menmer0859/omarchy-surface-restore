#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/common.sh"
require_omarchy
require_commands install python3

pam_file=/etc/pam.d/omarchy-lock-face
[[ -s "$pam_file" ]] || die "Face PAM service is missing: $pam_file"
[[ -s /etc/howdy/models/${USER}.dat ]] || die "Howdy model is missing for $USER; enroll with: sudo howdy -U $USER add"

plugin_root="$HOME/.config/omarchy/plugins/surface.lock"
plugins_root="$HOME/.config/omarchy/plugins"
if ! python3 "$root/scripts/check-lock-plugin-clones.py" "$plugins_root" "$plugin_root"; then
  die "Another Omarchy lock clone is installed. Disable it before installing this lock plugin."
fi

if [[ -e "$plugin_root" ]]; then
  backup_and_report "$plugin_root"
  [[ -e "$plugin_root/FaceAttemptPolicy.js" ]] || mark_new_path "$plugin_root/FaceAttemptPolicy.js"
else
  install -d -m 0755 "$plugin_root"
  mark_new_path "$plugin_root/manifest.json"
  mark_new_path "$plugin_root/Service.qml"
  mark_new_path "$plugin_root/LockView.qml"
  mark_new_path "$plugin_root/FaceAttemptPolicy.js"
fi

install -d -m 0755 "$plugin_root"
install -m 0644 "$root/assets/omarchy-lock/manifest.json" "$plugin_root/manifest.json"
install -m 0644 "$root/assets/omarchy-lock/Service.qml" "$plugin_root/Service.qml"
install -m 0644 "$root/assets/omarchy-lock/LockView.qml" "$plugin_root/LockView.qml"
install -m 0644 "$root/assets/omarchy-lock/FaceAttemptPolicy.js" "$plugin_root/FaceAttemptPolicy.js"

info "Installed the one-shot face lock plugin at $plugin_root"
printf 'Reload with: omarchy restart shell\n'
