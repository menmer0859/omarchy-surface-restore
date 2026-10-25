#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
help_output=$("$repo_root/install.sh" --help)
grep -q 'touch.*Restore Surface touchscreen' <<< "$help_output"
grep -q 'face.*--all.*--lock.*--sudo.*--polkit' <<< "$help_output"
grep -q 'consent-gated terminal sudo face authentication' <<< "$help_output"

# Face and touch become separately addressable module entrypoints. The legacy
# root CLI must forward to exactly those entries; neither implementation may
# smuggle the other module's setup into its own installer.
[[ -x "$repo_root/modules/face-auth/install.sh" ]]
[[ -x "$repo_root/modules/touch/install.sh" ]]
grep -F 'face|sudo-face|polkit-face|plugin-ui) exec "$root/modules/face-auth/install.sh" "$action" "$@"' "$repo_root/install.sh" >/dev/null
grep -F 'touch) exec "$root/modules/touch/install.sh"' "$repo_root/install.sh" >/dev/null
grep -q 'linux-surface-headers iptsd' "$repo_root/modules/touch/install.sh"
if grep -Eiq 'howdy|pam_howdy|polkit|omarchy-lock-face' "$repo_root/modules/touch/install.sh"; then
  echo 'touch installer contains face-auth setup' >&2
  exit 1
fi
if grep -Eiq 'linux-surface|iptsd' "$repo_root/modules/face-auth/scripts/install-face.sh"; then
  echo 'face installer contains touch setup' >&2
  exit 1
fi
[[ -x "$repo_root/scripts/install-sudo-face.sh" ]]
grep -q 'sudo-face|polkit-face|plugin-ui) exec' "$repo_root/install.sh"
[[ -x "$repo_root/scripts/install-polkit-face.sh" ]]
grep -q 'polkit-face)' "$repo_root/modules/face-auth/install.sh"
grep -q 'uninstall.sh face' "$repo_root/modules/face-auth/README.md"
grep -q 'uninstall.sh face' "$repo_root/modules/face-auth/README.zh-CN.md"
grep -q 'omarchy-polkit-howdy.py' "$repo_root/modules/face-auth/scripts/install-polkit-face.sh"
grep -q 'UI/PAM request aborts after 12 seconds' "$repo_root/modules/face-auth/scripts/install-lock-face.sh"
menu_output=$(printf '7\n' | "$repo_root/install.sh")
grep -q '2) Guided face setup' <<< "$menu_output"

if "$repo_root/install.sh" unknown >/dev/null 2>&1; then
  echo 'installer accepted an unknown action' >&2
  exit 1
fi


lock_install="$repo_root/modules/face-auth/scripts/install-lock-ui.sh"
grep -F 'SURFACE_SETUP_MODULE=face-auth' "$lock_install" >/dev/null
grep -F 'SURFACE_SETUP_BACKUP_ID=' "$lock_install" >/dev/null
grep -F 'install_face_ui_resources lock "$plugin_root"' "$lock_install" >/dev/null
grep -F 'mark_new_path "$plugin_root/FaceAttemptPolicy.js"' "$lock_install" >/dev/null

# Backing up an existing plugin directory preserves its complete old contents.
backup_temp=$(mktemp -d)
trap 'rm -rf -- "$backup_temp"' EXIT
old_plugin="$backup_temp/home/.config/omarchy/plugins/surface.lock"
mkdir -p "$old_plugin"
printf 'old service\n' > "$old_plugin/Service.qml"
printf '{"version":"1.0.0"}\n' > "$old_plugin/manifest.json"
SURFACE_SETUP_TESTING=1 SURFACE_SETUP_BACKUP_ROOT="$backup_temp/backups" SURFACE_SETUP_BACKUP_ID=upgrade-test \
  bash -c 'source "$1/lib/common.sh"; backup_and_report "$2"' _ "$repo_root" "$old_plugin" >/dev/null
saved_plugin="$backup_temp/backups/upgrade-test/${old_plugin#/}"
cmp "$old_plugin/Service.qml" "$saved_plugin/Service.qml"
cmp "$old_plugin/manifest.json" "$saved_plugin/manifest.json"

clone_temp=$(mktemp -d)
mkdir -p "$clone_temp/plugins/surface.lock" "$clone_temp/plugins/another-lock"
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/surface.lock/manifest.json"
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/another-lock/manifest.json"
if python3 "$repo_root/modules/face-auth/scripts/check-lock-plugin-clones.py" "$clone_temp/plugins" "$clone_temp/plugins/surface.lock"; then
  echo 'installer accepted a conflicting lock plugin clone' >&2
  exit 1
fi
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/surface.lock/manifest.json"
printf '{"omarchy":null}\n' > "$clone_temp/plugins/another-lock/manifest.json"
python3 "$repo_root/modules/face-auth/scripts/check-lock-plugin-clones.py" "$clone_temp/plugins" "$clone_temp/plugins/surface.lock"
mkdir -p "$clone_temp/plugins/.stale-lock.bak.20261026"
printf '{"omarchy":{"clonedFrom":"omarchy.lock"}}\n' > "$clone_temp/plugins/.stale-lock.bak.20261026/manifest.json"
python3 "$repo_root/modules/face-auth/scripts/check-lock-plugin-clones.py" "$clone_temp/plugins" "$clone_temp/plugins/surface.lock"
rm -rf -- "$clone_temp"

echo 'lock installer upgrade and clone checks passed'

echo 'installer smoke tests passed'
