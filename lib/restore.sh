#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_commands sudo find sort sed tar systemctl

backup_root=${SURFACE_SETUP_BACKUP_ROOT:-/var/backups/omarchy-surface-restore}
module_filter=''
if [[ $# -eq 0 ]]; then
  :
elif [[ $# -eq 2 && $1 == --module && ( $2 == face-auth || $2 == touch ) ]]; then
  module_filter=$2
else
  die 'Usage: restore.sh [--module face-auth|touch]'
fi
[[ -d "$backup_root" ]] || die "No backups found at $backup_root"
mapfile -t all_snapshots < <(sudo find "$backup_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
snapshots=()
legacy_snapshots=0
for candidate in "${all_snapshots[@]}"; do
  marker="$backup_root/$candidate/.surface_module"
  if [[ -z $module_filter ]]; then
    snapshots+=("$candidate")
  elif sudo test -f "$marker"; then
    owner=$(sudo cat "$marker")
    [[ $owner == "$module_filter" ]] && snapshots+=("$candidate")
  else
    ((legacy_snapshots+=1))
  fi
done
if ((${#snapshots[@]} == 0)); then
  [[ -z $module_filter ]] || die "No $module_filter snapshots found. Legacy snapshots have no module label; run restore.sh without --module and review the file list."
  die "No backups found at $backup_root"
fi

printf 'Available snapshots%s:\n' "${module_filter:+ for $module_filter}"
for index in "${!snapshots[@]}"; do
  printf '  %d) %s\n' "$((index + 1))" "${snapshots[$index]}"
done
if [[ -n $module_filter && $legacy_snapshots -gt 0 ]]; then
  printf 'Legacy snapshots without module labels are omitted; use the unfiltered restore after reviewing their paths.\n'
fi
read -r -p 'Snapshot number [1]: ' snapshot_number
snapshot_number=${snapshot_number:-1}
[[ "$snapshot_number" =~ ^[0-9]+$ ]] || die 'Enter a snapshot number from the list.'
((snapshot_number >= 1 && snapshot_number <= ${#snapshots[@]})) || die 'Snapshot number is outside the list.'
snapshot="$backup_root/${snapshots[$((snapshot_number - 1))]}"
printf '\nThe latest snapshot will restore these paths:\n'
sudo find "$snapshot" -mindepth 1 ! -name .created_paths ! -name .surface_module -print | sed "s#^$snapshot/##" | sort
if sudo test -s "$snapshot/.created_paths"; then
  printf '\nThe following paths created by the installer will be removed:\n'
  sudo sort -ru "$snapshot/.created_paths" | sed 's/^/  /'
fi
printf '\nThis restores saved files; it does not remove installed packages or kernels.\n'
ask_yes_no 'Restore the latest snapshot?' || die 'Restore cancelled.'
sudo tar --exclude=./.created_paths --exclude=./.surface_module -C "$snapshot" -cf - . | sudo tar -C / -xpf -
if sudo test -s "$snapshot/.created_paths"; then
  while IFS= read -r created_path; do
    [[ -n "$created_path" ]] || continue
    if sudo test -d "$created_path"; then
      sudo rmdir --ignore-fail-on-non-empty -- "$created_path"
    else
      sudo rm -f -- "$created_path"
    fi
  done < <(sudo sort -ru "$snapshot/.created_paths")
fi
info 'Saved files restored. Review permissions and restart the Omarchy shell or reboot as appropriate.'
sudo systemctl daemon-reload
