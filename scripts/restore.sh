#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_commands sudo find sort sed tar

backup_root=${SURFACE_SETUP_BACKUP_ROOT:-/var/backups/omarchy-surface-restore}
[[ -d "$backup_root" ]] || die "No backups found at $backup_root"
mapfile -t snapshots < <(sudo find "$backup_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
((${#snapshots[@]} > 0)) || die "No backups found at $backup_root"

printf 'Available snapshots:\n'
for index in "${!snapshots[@]}"; do
  printf '  %d) %s\n' "$((index + 1))" "${snapshots[$index]}"
done
read -r -p 'Snapshot number [1]: ' snapshot_number
snapshot_number=${snapshot_number:-1}
[[ "$snapshot_number" =~ ^[0-9]+$ ]] || die 'Enter a snapshot number from the list.'
((snapshot_number >= 1 && snapshot_number <= ${#snapshots[@]})) || die 'Snapshot number is outside the list.'
snapshot="$backup_root/${snapshots[$((snapshot_number - 1))]}"
printf '\nThe latest snapshot will restore these paths:\n'
sudo find "$snapshot" -mindepth 1 ! -name .created_paths -print | sed "s#^$snapshot/##" | sort
if sudo test -s "$snapshot/.created_paths"; then
  printf '\nThe following paths created by the installer will be removed:\n'
  sudo sort -u "$snapshot/.created_paths" | sed 's/^/  /'
fi
printf '\nThis restores saved files; it does not remove installed packages or kernels.\n'
ask_yes_no 'Restore the latest snapshot?' || die 'Restore cancelled.'
sudo tar --exclude=./.created_paths -C "$snapshot" -cf - . | sudo tar -C / -xpf -
if sudo test -s "$snapshot/.created_paths"; then
  while IFS= read -r created_path; do
    [[ -n "$created_path" ]] || continue
    if sudo test -d "$created_path"; then
      sudo rmdir --ignore-fail-on-non-empty -- "$created_path"
    else
      sudo rm -f -- "$created_path"
    fi
  done < <(sudo sort -u "$snapshot/.created_paths")
fi
info 'Saved files restored. Review permissions and restart the Omarchy shell or reboot as appropriate.'
