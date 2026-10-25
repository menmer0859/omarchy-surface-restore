#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/repo/lib" "$temp/repo/modules/face-auth/scripts" "$temp/bin" "$temp/backups/original" "$temp/target"
cp "$repo_root/lib/common.sh" "$temp/repo/lib/"
cp "$repo_root/modules/face-auth/install.sh" "$temp/repo/modules/face-auth/"
cp "$repo_root/modules/face-auth/scripts/face-install-state.py" "$temp/repo/modules/face-auth/scripts/"
cat > "$temp/repo/modules/face-auth/scripts/install-plugin-ui.sh" <<'UI'
#!/usr/bin/env bash
[[ ${1:-} != --check ]] || exit 0
printf 'new UI' > "$TEST_PLUGIN_FILE"
UI
printf '#!/usr/bin/env bash\nexec "$@"\n' > "$temp/bin/sudo"
printf '#!/usr/bin/env bash\nexit 1\n' > "$temp/bin/pacman"
chmod +x "$temp/bin"/* "$temp/repo/modules/face-auth/scripts/install-plugin-ui.sh"
export PATH="$temp/bin:$PATH" USER=alice SURFACE_SETUP_TESTING=1
export SURFACE_SETUP_FACE_STATE_FILE="$temp/state/face-auth.json" SURFACE_SETUP_BACKUP_ROOT="$temp/backups" SURFACE_SETUP_TARGET_ROOT="$temp/target"
export TEST_PLUGIN_FILE="$temp/target/plugin-ui"
state_script="$temp/repo/modules/face-auth/scripts/face-install-state.py"
printf '/plugin-ui\n' > "$temp/backups/original/.backed_up_paths"
: > "$temp/backups/original/.created_paths"
printf 'original UI' > "$temp/backups/original/plugin-ui"
printf 'old installed UI' > "$TEST_PLUGIN_FILE"
python3 "$state_script" --state-file "$SURFACE_SETUP_FACE_STATE_FILE" begin --user alice --backup-id original --integration lock >/dev/null
python3 "$state_script" --state-file "$SURFACE_SETUP_FACE_STATE_FILE" capture --backup-root "$SURFACE_SETUP_BACKUP_ROOT" --target-root "$SURFACE_SETUP_TARGET_ROOT" >/dev/null
python3 "$state_script" --state-file "$SURFACE_SETUP_FACE_STATE_FILE" status installed >/dev/null
bash "$temp/repo/modules/face-auth/install.sh" plugin-ui
python3 "$state_script" --state-file "$SURFACE_SETUP_FACE_STATE_FILE" verify --backup-root "$SURFACE_SETUP_BACKUP_ROOT" --target-root "$SURFACE_SETUP_TARGET_ROOT" >/dev/null
[[ $(cat "$TEST_PLUGIN_FILE") == 'new UI' ]]
[[ $(cat "$temp/backups/original/plugin-ui") == 'original UI' ]]
printf 'user modification' > "$TEST_PLUGIN_FILE"
if bash "$temp/repo/modules/face-auth/install.sh" plugin-ui >"$temp/conflict.log" 2>&1; then
  printf 'FAIL: UI update overwrote a later user change\n' >&2; exit 1
fi
[[ $(cat "$TEST_PLUGIN_FILE") == 'user modification' ]]
printf 'tracked UI upgrade tests passed\n'
