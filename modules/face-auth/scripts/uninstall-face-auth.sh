#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_root=$(cd "$module_root/../.." && pwd)
source "$repo_root/lib/common.sh"
state_script="$module_root/scripts/face-install-state.py"
restore_script="$module_root/scripts/restore-snapshot.py"
state_file=/var/lib/omarchy-surface-restore/face-auth.json
backup_root=/var/backups/omarchy-surface-restore
target_root=/
if [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]]; then
  state_file=${SURFACE_SETUP_FACE_STATE_FILE:-$state_file}
  backup_root=${SURFACE_SETUP_BACKUP_ROOT:-$backup_root}
  target_root=${SURFACE_SETUP_TARGET_ROOT:-$target_root}
  [[ $state_file == /tmp/* && $backup_root == /tmp/* && $target_root == /tmp/* ]] \
    || die 'Isolated test state and backup paths must be inside /tmp.'
fi
plugin_home=${HOME:?HOME is required}
if [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]]; then
  plugin_home=${SURFACE_SETUP_TEST_HOME:-}
  [[ $plugin_home == /* && $plugin_home != *..* ]] || die 'Isolated test plugin home must be an absolute safe path.'
  plugin_home_path="$target_root$plugin_home"
else
  plugin_home_path=$plugin_home
fi

require_commands sudo python3 pacman grep install systemctl id
state_json=$(sudo python3 "$state_script" --state-file "$state_file" show 2>/dev/null) || {
  die 'No trusted face-auth install record exists. Automatic uninstall is unavailable for legacy installs; review the documented manual cleanup steps.'
}
status=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' <<<"$state_json")
if [[ $status == uninstalled ]]; then
  printf 'Face authentication is already uninstalled.\n'
  exit 0
fi
transaction_id=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"$state_json")
enrolling_user=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"])' <<<"$state_json")
integrations=$(python3 -c 'import json,sys; print(", ".join(json.load(sys.stdin)["integrations"]))' <<<"$state_json")
snapshot="$backup_root/$transaction_id"
[[ ${USER:-$(id -un)} == "$enrolling_user" ]] || die "This face-auth transaction belongs to $enrolling_user; run the uninstaller from that account."
if ! sudo test -d "$snapshot"; then
  [[ $status == installing ]] || die "The protected backup snapshot is missing: $snapshot"
  sudo install -d -m 0700 "$snapshot"
  sudo touch "$snapshot/.created_paths" "$snapshot/.backed_up_paths"
  sudo chmod 0600 "$snapshot/.created_paths" "$snapshot/.backed_up_paths"
fi

verification_args=()
[[ $status != uninstalling ]] || verification_args+=(--allow-restored)
if ! verification=$(sudo python3 "$state_script" --state-file "$state_file" verify \
  --backup-root "$backup_root" --target-root "$target_root" "${verification_args[@]}" 2>&1); then
  printf '%s\n' "$verification" >&2
  die 'Uninstall stopped before changing files because the install state is incomplete or its files changed afterward. Review the listed paths and preserve your changes before retrying.'
fi

snapshot_tracks_path() {
  local path=${1:?Usage: snapshot_tracks_path ABSOLUTE_PATH}
  sudo grep -Fxq -- "$path" "$snapshot/.created_paths" 2>/dev/null \
    || sudo grep -Fxq -- "$path" "$snapshot/.backed_up_paths" 2>/dev/null
}

graphical_changes=false
plugin_listing='[]'
if snapshot_tracks_path "$plugin_home/.config/omarchy/shell.json" \
  || snapshot_tracks_path "$plugin_home/.config/omarchy/plugins/surface.lock" \
  || snapshot_tracks_path "$plugin_home/.config/omarchy/plugins/$enrolling_user.polkit"; then
  graphical_changes=true
  require_commands omarchy omarchy-shell jq
  locked=$(omarchy-shell lock isLocked) || die 'Could not confirm lock state; unlock the desktop before uninstalling graphical authentication.'
  [[ $locked == false ]] || die 'Unlock the desktop before uninstalling graphical authentication.'
  plugin_listing=$(omarchy-shell shell listPlugins) || die 'Could not contact the Omarchy plugin registry; no files were changed.'
  jq -e 'type == "array"' <<<"$plugin_listing" >/dev/null || die 'Invalid Omarchy plugin registry response; no files were changed.'
fi

packages_present_before=$(python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)["packages_present_before"]))' <<<"$state_json")
planned_packages=()
for package in howdy-git python-dlib-git; do
  [[ " $packages_present_before " == *" $package "* ]] && continue
  pacman -Qq "$package" >/dev/null 2>&1 && planned_packages+=("$package")
done
mapfile -t recorded_paths < <(sudo cat "$snapshot/.backed_up_paths" "$snapshot/.created_paths" 2>/dev/null | sort -u)
model_path="/etc/howdy/models/$enrolling_user.dat"
model_path="$target_root$model_path"
model_action='No new model is recorded for this transaction.'
if snapshot_tracks_path "/etc/howdy/models/$enrolling_user.dat" && { sudo test -e "$model_path" || sudo test -L "$model_path"; }; then
  model_action="Newly enrolled model will be archived at $snapshot/models/$enrolling_user.dat."
fi

printf 'This will uninstall the recorded face-authentication setup.\n'
printf 'Integrations: %s\n' "$integrations"
printf 'Recorded files to restore or remove:\n'
if ((${#recorded_paths[@]})); then printf '  %s\n' "${recorded_paths[@]}"; else printf '  none\n'; fi
if [[ " $integrations " == *lock* ]]; then printf '  user plugin: %s/.config/omarchy/plugins/surface.lock\n' "$plugin_home"; fi
if [[ " $integrations " == *polkit* ]]; then printf '  user plugin: %s/.config/omarchy/plugins/%s.polkit\n' "$plugin_home" "$enrolling_user"; fi
printf '%s\n' "$model_action"
if ((${#planned_packages[@]})); then
  printf 'Packages to offer for non-cascading removal: %s\n' "${planned_packages[*]}"
else
  printf 'Packages to remove: none (pre-existing or not installed).\n'
fi
printf 'Touchscreen support, linux-surface, iptsd, and Quickshell are not part of this uninstall.\n\n'
ask_yes_no 'Continue with face-auth uninstall?' || die 'Uninstall cancelled; no changes were made.'

sudo python3 "$state_script" --state-file "$state_file" status uninstalling >/dev/null

archive_model() {
  local model_path="/etc/howdy/models/$enrolling_user.dat"
  local destination="$snapshot/models/$enrolling_user.dat"
  local actual_model="$target_root${model_path}"
  if snapshot_tracks_path "$model_path" && { sudo test -e "$actual_model" || sudo test -L "$actual_model"; }; then
    sudo test ! -L "$actual_model" || die "Refusing to archive a symlink face model: $model_path"
    sudo install -d -m 0700 "$snapshot/models"
    if ! sudo test -e "$destination"; then sudo mv -- "$actual_model" "$destination"; fi
  fi
}

remove_user_plugin() {
  local plugin_id=$1 plugin_logical_path="$plugin_home/.config/omarchy/plugins/$1"
  local plugin_path="$plugin_home_path/.config/omarchy/plugins/$1"
  local destination="$snapshot/removed-plugins/$1"
  [[ -e $plugin_path || -L $plugin_path ]] || return 0
  snapshot_tracks_path "$plugin_logical_path" || return 0
  if command -v omarchy-shell >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    if jq -e --arg id "$plugin_id" 'any(.[]; .id == $id and .enabled == true)' <<<"$plugin_listing" >/dev/null; then
      omarchy plugin disable "$plugin_id"
    fi
    sudo install -d -m 0700 "$snapshot/removed-plugins"
    sudo mv -- "$plugin_path" "$destination"
    omarchy-shell shell rescanPlugins >/dev/null
  else
    die "Omarchy plugin tools are required to safely remove $plugin_id."
  fi
}

archive_model
remove_user_plugin surface.lock
remove_user_plugin "$enrolling_user.polkit"

sudo python3 "$restore_script" --snapshot "$snapshot" --target-root "$target_root"
sudo systemctl daemon-reload

for package in howdy-git python-dlib-git; do
  [[ " $packages_present_before " == *" $package "* ]] && continue
  if pacman -Qq "$package" >/dev/null 2>&1; then
    if [[ ${SURFACE_SETUP_TESTING:-0} == 1 ]]; then
      if pacman -R --noconfirm "$package"; then removal_status=0; else removal_status=$?; fi
    else
      if sudo pacman -R --noconfirm "$package"; then removal_status=0; else removal_status=$?; fi
    fi
    if [[ $removal_status -eq 0 ]]; then
      info "Removed installer-owned package $package without cascading dependencies."
    else
      warn "Kept $package because pacman refused its removal (it may now be shared or required elsewhere)."
    fi
  fi
done

if [[ $graphical_changes == true ]]; then
  locked=$(omarchy-shell lock isLocked) || die 'Configuration restored, but the shell could not be reloaded; unlock the desktop and rerun the uninstaller.'
  [[ $locked == false ]] || die 'Configuration restored; unlock the desktop and rerun the uninstaller to reload the shell.'
  omarchy restart shell
fi

sudo python3 "$state_script" --state-file "$state_file" status uninstalled >/dev/null
info 'Recorded face-authentication configuration has been removed. The enrolled model is retained in the protected backup.'
printf 'Before closing this terminal, verify password authentication with sudo -k -v and, if selected, pkexec /usr/bin/id and a lock-screen password test.\n'
