#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
help_output=$("$repo_root/install.sh" --help)
grep -q 'touch|face|sudo-face|polkit-face|all|check' <<< "$help_output"
grep -q 'explicit-consent Howdy for terminal sudo' <<< "$help_output"
[[ -x "$repo_root/scripts/install-sudo-face.sh" ]]
grep -q 'sudo-face) exec' "$repo_root/install.sh"
[[ -x "$repo_root/scripts/install-polkit-face.sh" ]]
grep -q 'polkit-face) exec' "$repo_root/install.sh"
grep -q 'omarchy-polkit-howdy.py' "$repo_root/scripts/install-polkit-face.sh"
grep -q 'request one face scan (up to 12 seconds)' "$repo_root/scripts/install-face.sh"
menu_output=$(printf '7\n' | "$repo_root/install.sh")
grep -q '3) Enable consent-gated face authentication for sudo' <<< "$menu_output"
grep -q '4) Enable consent-gated face authentication for graphical admin prompts' <<< "$menu_output"

if "$repo_root/install.sh" unknown >/dev/null 2>&1; then
  echo 'installer accepted an unknown action' >&2
  exit 1
fi


lock_install="$repo_root/scripts/install-lock-ui.sh"
grep -F 'install -m 0644 "$root/assets/omarchy-lock/FaceAttemptPolicy.js" "$plugin_root/FaceAttemptPolicy.js"' "$lock_install" >/dev/null
grep -F 'mark_new_path "$plugin_root/FaceAttemptPolicy.js"' "$lock_install" >/dev/null

# Backing up an existing plugin directory preserves its complete old contents.
backup_temp=$(mktemp -d)
trap 'rm -rf -- "$backup_temp"' EXIT
old_plugin="$backup_temp/home/.config/omarchy/plugins/surface.lock"
mkdir -p "$old_plugin"
printf 'old service\n' > "$old_plugin/Service.qml"
printf '{"version":"1.0.0"}\n' > "$old_plugin/manifest.json"
SURFACE_SETUP_BACKUP_ROOT="$backup_temp/backups" SURFACE_SETUP_BACKUP_ID=upgrade-test \
  bash -c 'source "$1/scripts/common.sh"; backup_and_report "$2"' _ "$repo_root" "$old_plugin" >/dev/null
saved_plugin="$backup_temp/backups/upgrade-test/${old_plugin#/}"
cmp "$old_plugin/Service.qml" "$saved_plugin/Service.qml"
cmp "$old_plugin/manifest.json" "$saved_plugin/manifest.json"

clone_temp=$(mktemp -d)
mkdir -p "$clone_temp/plugins/surface.lock" "$clone_temp/plugins/another-lock"
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/surface.lock/manifest.json"
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/another-lock/manifest.json"
if python3 "$repo_root/scripts/check-lock-plugin-clones.py" "$clone_temp/plugins" "$clone_temp/plugins/surface.lock"; then
  echo 'installer accepted a conflicting lock plugin clone' >&2
  exit 1
fi
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/surface.lock/manifest.json"
printf '{"omarchy":null}\n' > "$clone_temp/plugins/another-lock/manifest.json"
python3 "$repo_root/scripts/check-lock-plugin-clones.py" "$clone_temp/plugins" "$clone_temp/plugins/surface.lock"
rm -rf -- "$clone_temp"

echo 'lock installer upgrade and clone checks passed'

echo 'installer smoke tests passed'
