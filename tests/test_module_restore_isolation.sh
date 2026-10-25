#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/backups/20261023-face" "$temp/backups/20261023-touch" "$temp/backups/20261023-legacy"
printf 'face-auth\n' > "$temp/backups/20261023-face/.surface_module"
printf 'touch\n' > "$temp/backups/20261023-touch/.surface_module"
cat > "$temp/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
exec "$@"
SUDO
chmod +x "$temp/bin/sudo"
set +e
output=$(printf '1\nn\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 SURFACE_SETUP_BACKUP_ROOT="$temp/backups" \
  bash "$repo_root/scripts/restore.sh" --module face-auth 2>&1)
status=$?
set -e
[[ $status -ne 0 ]]
grep -q '20261023-face' <<< "$output"
if grep -q '20261023-touch' <<< "$output"; then echo 'touch snapshot leaked into face selection' >&2; exit 1; fi
if grep -q '20261023-legacy' <<< "$output"; then echo 'legacy snapshot was guessed into module selection' >&2; exit 1; fi
grep -qi 'legacy' <<< "$output"
printf 'module restore selection isolation tests passed\n'
