#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/backups/20261005-000000"
cat > "$temp/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
if [[ "$*" == 'tar -C / -xpf -' ]]; then
  cat >/dev/null
  exit 0
fi
exec "$@"
SUDO
cat > "$temp/bin/systemctl" <<'SYSTEMCTL'
#!/usr/bin/env bash
[[ "$*" == 'daemon-reload' ]]
SYSTEMCTL
chmod +x "$temp/bin/sudo" "$temp/bin/systemctl"

created_dir="$temp/etc/polkit-agent-helper@.service.d"
created_file="$created_dir/60-omarchy-surface-face.conf"
plugin_dir="$temp/home/.config/omarchy/plugins/surface.lock"
policy_file="$plugin_dir/FaceAttemptPolicy.js"
mkdir -p "$created_dir" "$plugin_dir"
printf '[Service]\n' > "$created_file"
printf 'module.exports = {};\n' > "$policy_file"
printf '%s\n%s\n%s\n' "$created_dir" "$created_file" "$policy_file" > "$temp/backups/20261005-000000/.created_paths"

printf '1\ny\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_BACKUP_ROOT="$temp/backups" \
  bash "$repo_root/scripts/restore.sh" >/dev/null

[[ ! -e "$created_file" ]]
[[ ! -e "$created_dir" ]]
[[ ! -e "$policy_file" ]]

echo 'restore created-path tests passed'
