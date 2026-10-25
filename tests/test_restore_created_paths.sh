#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/backups/20261005-000000"
cat > "$temp/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
if [[ ${1:-} == python3 && ${2:-} == */restore-snapshot.py ]]; then
  script=$2
  shift 2
  exec python3 "$script" "$@" --target-root "$RESTORE_TARGET_ROOT"
fi
exec "$@"
SUDO
cat > "$temp/bin/systemctl" <<'SYSTEMCTL'
#!/usr/bin/env bash
[[ "$*" == 'daemon-reload' ]]
SYSTEMCTL
chmod +x "$temp/bin/sudo" "$temp/bin/systemctl"

target="$temp/target"
mkdir -p "$target"
chmod 0755 "$target"
created_dir="$target/etc/polkit-agent-helper@.service.d"
created_file="$created_dir/60-omarchy-surface-face.conf"
plugin_dir="$target/home/.config/omarchy/plugins/surface.lock"
policy_file="$plugin_dir/FaceAttemptPolicy.js"
mkdir -p "$created_dir" "$plugin_dir"
printf '[Service]\n' > "$created_file"
printf 'module.exports = {};\n' > "$policy_file"
printf '%s\n%s\n%s\n' '/etc/polkit-agent-helper@.service.d' '/etc/polkit-agent-helper@.service.d/60-omarchy-surface-face.conf' '/home/.config/omarchy/plugins/surface.lock/FaceAttemptPolicy.js' > "$temp/backups/20261005-000000/.created_paths"

printf '1\ny\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 RESTORE_TARGET_ROOT="$target" SURFACE_SETUP_BACKUP_ROOT="$temp/backups" \
  bash "$repo_root/scripts/restore.sh" >/dev/null

[[ ! -e "$created_file" ]]
[[ ! -e "$created_dir" ]]
[[ ! -e "$policy_file" ]]
[[ $(stat -c '%a' "$target") == 755 ]]

echo 'restore created-path tests passed'
