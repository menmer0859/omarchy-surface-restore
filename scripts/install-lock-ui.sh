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
for manifest in "$plugins_root"/*/manifest.json; do
  [[ -f "$manifest" ]] || continue
  [[ "$(dirname "$manifest")" == "$plugin_root" ]] && continue
  if python3 - "$manifest" <<'PY'
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)
raise SystemExit(0 if data.get("omarchy", {}).get("clonedFrom") == "omarchy.lock" else 1)
PY
  then
    die "Another Omarchy lock clone is installed at $(dirname "$manifest"). Disable it before installing this lock plugin."
  fi
done

if [[ -e "$plugin_root" ]]; then
  backup_and_report "$plugin_root"
else
  install -d -m 0755 "$plugin_root"
  mark_new_path "$plugin_root/manifest.json"
  mark_new_path "$plugin_root/Service.qml"
  mark_new_path "$plugin_root/LockView.qml"
fi

install -d -m 0755 "$plugin_root"
install -m 0644 "$root/assets/omarchy-lock/manifest.json" "$plugin_root/manifest.json"
install -m 0644 "$root/assets/omarchy-lock/Service.qml" "$plugin_root/Service.qml"
install -m 0644 "$root/assets/omarchy-lock/LockView.qml" "$plugin_root/LockView.qml"

info "Installed the face-first lock plugin at $plugin_root"
printf 'Reload with: omarchy restart shell\n'
