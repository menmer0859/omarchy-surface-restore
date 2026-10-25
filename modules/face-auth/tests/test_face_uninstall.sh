#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
export SURFACE_SETUP_TEST_HOME=/home/alice
script="$repo_root/modules/face-auth/scripts/uninstall-face-auth.sh"
state_script="$repo_root/modules/face-auth/scripts/face-install-state.py"
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "${3:-value}: expected <$2>, got <$1>"; }

mkdir -p "$temp/bin" "$temp/target/etc/pam.d" "$temp/target/etc/howdy/models" "$temp/backups/run-1"
printf 'old PAM stack\n' > "$temp/backups/run-1/etc-pam-sudo"
mkdir -p "$temp/backups/run-1/etc/pam.d"
mv "$temp/backups/run-1/etc-pam-sudo" "$temp/backups/run-1/etc/pam.d/sudo"
printf '/etc/pam.d/sudo\n' > "$temp/backups/run-1/.backed_up_paths"
printf 'face PAM stack\n' > "$temp/target/etc/pam.d/sudo"
printf 'model-data\n' > "$temp/target/etc/howdy/models/alice.dat"
printf '%s\n%s\n' '/usr/local/libexec/omarchy-test-helper' '/etc/howdy/models/alice.dat' > "$temp/backups/run-1/.created_paths"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$temp/state/face-auth.json" begin \
  --user alice --backup-id run-1 --package-present python-dlib-git --integration sudo >/dev/null
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$temp/state/face-auth.json" status installed >/dev/null
mkdir -p "$temp/target/usr/local/libexec"
printf 'new helper\n' > "$temp/target/usr/local/libexec/omarchy-test-helper"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$temp/state/face-auth.json" capture \
  --backup-root "$temp/backups" --target-root "$temp/target" >/dev/null

cat > "$temp/bin/pacman" <<'PACMAN'
#!/usr/bin/env bash
set -euo pipefail
packages="$PACMAN_STATE"
if [[ ${1:-} == -Qq ]]; then
  grep -Fxq -- "${2:-}" "$packages"
elif [[ ${1:-} == -R ]]; then
  [[ ${2:-} != -Rns && ${2:-} != -Rsc ]]
  [[ ${PACMAN_REFUSE_PACKAGE:-} != "$3" ]] || exit 1
  grep -Fxv -- "$3" "$packages" > "$packages.new" || true
  mv "$packages.new" "$packages"
else
  exit 2
fi
PACMAN
cat > "$temp/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
exec "$@"
SUDO
cat > "$temp/bin/systemctl" <<'SYSTEMCTL'
#!/usr/bin/env bash
if [[ -n ${SYSTEMCTL_FAIL_MARKER:-} && ! -e $SYSTEMCTL_FAIL_MARKER ]]; then
  touch "$SYSTEMCTL_FAIL_MARKER"
  exit 1
fi
[[ "$*" == 'daemon-reload' ]]
SYSTEMCTL
cat > "$temp/bin/omarchy-shell" <<'OMARCHY_SHELL'
#!/usr/bin/env bash
if [[ "$*" == 'lock isLocked' ]]; then printf '%s\n' "${TEST_LOCK_STATE:-false}"; exit 0; fi
if [[ "$*" == 'shell listPlugins' ]]; then
  [[ ${TEST_PLUGIN_IPC_FAIL:-0} != 1 ]] || exit 1
  printf '[]\n'; exit 0
fi
if [[ "$*" == 'shell rescanPlugins' ]]; then exit 0; fi
exit 2
OMARCHY_SHELL
cat > "$temp/bin/omarchy" <<'OMARCHY'
#!/usr/bin/env bash
[[ "$*" == 'plugin disable surface.lock' || "$*" == 'plugin disable alice.polkit' || "$*" == 'restart shell' ]]
OMARCHY
chmod +x "$temp/bin"/*

packages="$temp/packages"
printf 'howdy-git\npython-dlib-git\n' > "$packages"

if PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 SURFACE_SETUP_FACE_STATE_FILE="$temp/no-state.json" \
  SURFACE_SETUP_BACKUP_ROOT="$temp/backups" SURFACE_SETUP_TARGET_ROOT="$temp/target" \
  bash "$script" >"$temp/no-state.log" 2>&1; then
  fail 'uninstaller accepted a legacy install without a trusted ledger'
fi
grep -q 'No trusted face-auth install record' "$temp/no-state.log" || { cat "$temp/no-state.log" >&2; fail 'legacy refusal was not actionable'; }

printf 'n\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice PACMAN_STATE="$packages" \
  SURFACE_SETUP_FACE_STATE_FILE="$temp/state/face-auth.json" SURFACE_SETUP_BACKUP_ROOT="$temp/backups" \
  SURFACE_SETUP_TARGET_ROOT="$temp/target" bash "$script" >"$temp/cancel.log" 2>&1 || true
assert_eq "$(cat "$temp/target/etc/pam.d/sudo")" 'face PAM stack' 'cancel preserves PAM'
assert_eq "$(cat "$temp/state/face-auth.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')" installed 'cancel preserves state'

set +e
printf 'y\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice PACMAN_STATE="$packages" \
  SURFACE_SETUP_FACE_STATE_FILE="$temp/state/face-auth.json" SURFACE_SETUP_BACKUP_ROOT="$temp/backups" \
  SURFACE_SETUP_TARGET_ROOT="$temp/target" bash "$script" >"$temp/uninstall.log" 2>&1
uninstall_rc=$?
set -e
if (( uninstall_rc != 0 )); then cat "$temp/uninstall.log" >&2; exit "$uninstall_rc"; fi
assert_eq "$(cat "$temp/target/etc/pam.d/sudo")" 'old PAM stack' 'restored PAM'
[[ ! -e "$temp/target/usr/local/libexec/omarchy-test-helper" ]] || fail 'new helper was not removed'
assert_eq "$(cat "$temp/backups/run-1/models/alice.dat")" 'model-data' 'archived model'
assert_eq "$(cat "$packages")" 'python-dlib-git' 'preserved pre-existing package'
assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$temp/state/face-auth.json")" uninstalled 'final transaction state'
PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice PACMAN_STATE="$packages" \
  SURFACE_SETUP_FACE_STATE_FILE="$temp/state/face-auth.json" SURFACE_SETUP_BACKUP_ROOT="$temp/backups" \
  SURFACE_SETUP_TARGET_ROOT="$temp/target" bash "$script" >"$temp/second.log" 2>&1
grep -q 'already uninstalled' "$temp/second.log" || fail 'second uninstall was not idempotent'

# A newly-created plugin directory is archived out of Omarchy's discovery path
# and its project-owned tree is removed without leaving a hidden .bak clone.
plugin_temp="$temp/plugin-case"
plugin_target="$plugin_temp/target"
plugin_path="$plugin_target/home/alice/.config/omarchy/plugins/surface.lock"
mkdir -p "$plugin_temp/backups/plugin-run" "$plugin_path"
printf '{"id":"surface.lock"}\n' > "$plugin_path/manifest.json"
printf '%s\n' '/home/alice/.config/omarchy/plugins/surface.lock' '/home/alice/.config/omarchy/plugins/surface.lock/manifest.json' > "$plugin_temp/backups/plugin-run/.created_paths"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$plugin_temp/state/face-auth.json" begin \
  --user alice --backup-id plugin-run --package-present howdy-git --package-present python-dlib-git --integration lock >/dev/null
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$plugin_temp/state/face-auth.json" status installed >/dev/null
: > "$plugin_temp/backups/plugin-run/.backed_up_paths"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$plugin_temp/state/face-auth.json" capture \
  --backup-root "$plugin_temp/backups" --target-root "$plugin_target" >/dev/null
for failure in locked ipc; do
  lock_state=false; ipc_fail=0
  [[ $failure != locked ]] || lock_state=true
  [[ $failure != ipc ]] || ipc_fail=1
  if printf 'y\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice PACMAN_STATE="$packages" \
    TEST_LOCK_STATE="$lock_state" TEST_PLUGIN_IPC_FAIL="$ipc_fail" \
    SURFACE_SETUP_FACE_STATE_FILE="$plugin_temp/state/face-auth.json" \
    SURFACE_SETUP_BACKUP_ROOT="$plugin_temp/backups" SURFACE_SETUP_TARGET_ROOT="$plugin_target" \
    bash "$script" >"$plugin_temp/$failure.log" 2>&1; then
    fail "graphical uninstall proceeded with $failure desktop state"
  fi
  [[ -f "$plugin_path/manifest.json" ]] || fail "$failure refusal moved a plugin"
  assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$plugin_temp/state/face-auth.json")" installed "$failure refusal leaves transaction intact"
done
set +e
printf 'y\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" SURFACE_SETUP_TEST_HOME=/home/alice USER=alice PACMAN_STATE="$packages" \
  SURFACE_SETUP_FACE_STATE_FILE="$plugin_temp/state/face-auth.json" \
  SURFACE_SETUP_BACKUP_ROOT="$plugin_temp/backups" SURFACE_SETUP_TARGET_ROOT="$plugin_target" \
  bash "$script" >"$plugin_temp/uninstall.log" 2>&1
plugin_rc=$?
set -e
if (( plugin_rc != 0 )); then cat "$plugin_temp/uninstall.log" >&2; exit "$plugin_rc"; fi
[[ ! -e "$plugin_path" ]] || fail 'project lock plugin was left active on disk'
[[ -e "$plugin_temp/backups/plugin-run/removed-plugins/surface.lock/manifest.json" ]] || fail 'plugin was not retained outside Omarchy discovery'
[[ ! -e "$plugin_target/home/alice/.config/omarchy/plugins/.surface.lock.bak.test" ]] || fail 'hidden plugin backup was left in discovery'

refuse_temp="$temp/refuse-case"
mkdir -p "$refuse_temp/backups/run-refuse" "$refuse_temp/target"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$refuse_temp/state/face-auth.json" begin \
  --user alice --backup-id run-refuse --integration sudo >/dev/null
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$refuse_temp/state/face-auth.json" status installed >/dev/null
: > "$refuse_temp/backups/run-refuse/.created_paths"
: > "$refuse_temp/backups/run-refuse/.backed_up_paths"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$refuse_temp/state/face-auth.json" capture \
  --backup-root "$refuse_temp/backups" --target-root "$refuse_temp/target" >/dev/null
printf 'python-dlib-git\n' > "$refuse_temp/packages"
printf 'y\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice \
  PACMAN_STATE="$refuse_temp/packages" PACMAN_REFUSE_PACKAGE=python-dlib-git \
  SURFACE_SETUP_FACE_STATE_FILE="$refuse_temp/state/face-auth.json" \
  SURFACE_SETUP_BACKUP_ROOT="$refuse_temp/backups" SURFACE_SETUP_TARGET_ROOT="$refuse_temp/target" \
  bash "$script" >"$refuse_temp/uninstall.log" 2>&1
assert_eq "$(cat "$refuse_temp/packages")" python-dlib-git 'package required elsewhere is retained'
grep -q 'Kept python-dlib-git because pacman refused' "$refuse_temp/uninstall.log" || fail 'package refusal was not reported'

conflict_temp="$temp/conflict-case"
mkdir -p "$conflict_temp/backups/conflict-run/etc/pam.d" "$conflict_temp/target/etc/pam.d"
printf 'pre-install policy\n' > "$conflict_temp/backups/conflict-run/etc/pam.d/sudo"
printf '/etc/pam.d/sudo\n' > "$conflict_temp/backups/conflict-run/.backed_up_paths"
: > "$conflict_temp/backups/conflict-run/.created_paths"
printf 'installed policy\n' > "$conflict_temp/target/etc/pam.d/sudo"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$conflict_temp/state/face-auth.json" begin \
  --user alice --backup-id conflict-run --integration sudo >/dev/null
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$conflict_temp/state/face-auth.json" capture \
  --backup-root "$conflict_temp/backups" --target-root "$conflict_temp/target" >/dev/null
printf 'user-edited policy\n' > "$conflict_temp/target/etc/pam.d/sudo"
if SURFACE_SETUP_TESTING=1 PATH="$temp/bin:$PATH" HOME="$temp/home/alice" USER=alice \
  PACMAN_STATE="$packages" SURFACE_SETUP_FACE_STATE_FILE="$conflict_temp/state/face-auth.json" \
  SURFACE_SETUP_BACKUP_ROOT="$conflict_temp/backups" SURFACE_SETUP_TARGET_ROOT="$conflict_temp/target" \
  bash "$script" >"$conflict_temp/uninstall.log" 2>&1; then
  fail 'uninstaller overwrote a user-edited managed file'
fi
grep -q '/etc/pam.d/sudo' "$conflict_temp/uninstall.log" || fail 'changed managed path was not listed'
assert_eq "$(cat "$conflict_temp/target/etc/pam.d/sudo")" 'user-edited policy' 'user edit preserved'

retry_temp="$temp/retry-case"
mkdir -p "$retry_temp/backups/retry-run/etc/pam.d" "$retry_temp/target/etc/pam.d"
printf 'old PAM\n' > "$retry_temp/backups/retry-run/etc/pam.d/sudo"
printf '/etc/pam.d/sudo\n' > "$retry_temp/backups/retry-run/.backed_up_paths"
: > "$retry_temp/backups/retry-run/.created_paths"
printf 'installed PAM\n' > "$retry_temp/target/etc/pam.d/sudo"
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$retry_temp/state/face-auth.json" begin \
  --user alice --backup-id retry-run --integration sudo >/dev/null
SURFACE_SETUP_TESTING=1 python3 "$state_script" --state-file "$retry_temp/state/face-auth.json" capture \
  --backup-root "$retry_temp/backups" --target-root "$retry_temp/target" >/dev/null
retry_marker="$retry_temp/systemctl-failed-once"
printf 'y\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice \
  PACMAN_STATE="$packages" SYSTEMCTL_FAIL_MARKER="$retry_marker" \
  SURFACE_SETUP_FACE_STATE_FILE="$retry_temp/state/face-auth.json" \
  SURFACE_SETUP_BACKUP_ROOT="$retry_temp/backups" SURFACE_SETUP_TARGET_ROOT="$retry_temp/target" \
  bash "$script" >"$retry_temp/first.log" 2>&1 && fail 'injected cleanup failure was not surfaced'
assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$retry_temp/state/face-auth.json")" uninstalling 'interrupted uninstall state'
printf 'y\n' | PATH="$temp/bin:$PATH" SURFACE_SETUP_TESTING=1 HOME="$temp/home/alice" USER=alice \
  PACMAN_STATE="$packages" SYSTEMCTL_FAIL_MARKER="$retry_marker" \
  SURFACE_SETUP_FACE_STATE_FILE="$retry_temp/state/face-auth.json" \
  SURFACE_SETUP_BACKUP_ROOT="$retry_temp/backups" SURFACE_SETUP_TARGET_ROOT="$retry_temp/target" \
  bash "$script" >"$retry_temp/retry.log" 2>&1
assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$retry_temp/state/face-auth.json")" uninstalled 'retried uninstall completion'

echo 'face uninstall transaction tests passed'
