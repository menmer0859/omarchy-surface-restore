#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "${3:-value}: expected <$2>, got <$1>"; }

new_fixture() {
  local root="$1"
  mkdir -p "$root/modules/face-auth/scripts"
  cp "$repo_root/modules/face-auth/scripts/run-face-setup.sh" "$root/modules/face-auth/scripts/"
  cp "$repo_root/modules/face-auth/scripts/face-install-state.py" "$root/modules/face-auth/scripts/"
  mkdir -p "$root/lib"
  cp "$repo_root/lib/common.sh" "$root/lib/"
  cat > "$root/modules/face-auth/scripts/face-setup-status.py" <<'PY'
import json, os
from pathlib import Path
state = dict(item.split("=", 1) for item in Path(os.environ["TEST_STATE_FILE"]).read_text().split())
if os.environ.get("TEST_DELAY_READY") == "1" and state.get("lock") == "1":
    counter = Path(os.environ["TEST_STATE_FILE"] + ".reads")
    count = int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(count + 1))
    if count < 2:
        state["lock"] = "0"
def yes(key): return state.get(key) == "1"
print(json.dumps({
    "schemaVersion": 1,
    "camera": {"available": yes("camera"), "accessible": yes("camera")},
    "howdy": {"ready": yes("howdy")},
    "lock": {"ready": yes("lock"), "passwordFallback": yes("password")},
    "sudo": {"ready": yes("sudo")},
    "polkit": {"ready": yes("polkit")},
}))
PY
  for name in install-howdy-base.sh install-lock-face.sh install-sudo-face.sh install-polkit-face.sh; do
    local state_key=${name#install-}; state_key=${state_key%.sh}; state_key=${state_key//-/_}
    case "$name" in
      install-howdy-base.sh) state_key=howdy ;;
      install-lock-face.sh) state_key=lock ;;
      install-sudo-face.sh) state_key=sudo ;;
      install-polkit-face.sh) state_key=polkit ;;
    esac
    cat > "$root/modules/face-auth/scripts/$name" <<SH
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' '$state_key' >> "\$TEST_LOG"
[[ \${FAIL_AT:-} != '$state_key' ]] || exit 9
python3 - "\$TEST_STATE_FILE" '$state_key' <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]); state=dict(item.split('=',1) for item in p.read_text().split()); state[sys.argv[2]]='1'
p.write_text(' '.join(f'{k}={v}' for k,v in state.items()))
PY
SH
    chmod +x "$root/modules/face-auth/scripts/$name"
  done
}

run_case() {
  local label="$1" selection="$2" initial="$3" expected_rc="$4" expected_log="$5" fail_at="${6:-}"
  local root="$temp/$label" state="$temp/$label.state" log="$temp/$label.log"
  new_fixture "$root"
  mkdir -p "$root/bin"
  cat > "$root/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
exec "$@"
SUDO
  cat > "$root/bin/pacman" <<'PACMAN'
#!/usr/bin/env bash
[[ "$1" == '-Qq' ]] && exit 1
exit 2
PACMAN
  chmod +x "$root/bin/sudo" "$root/bin/pacman"
  printf '%s\n' "$initial" > "$state"
  : > "$log"
  set +e
  # shellcheck disable=SC2086
  TEST_DELAY_READY="${TEST_DELAY_READY:-0}" TEST_STATE_FILE="$state" TEST_LOG="$log" FAIL_AT="$fail_at" PATH="$root/bin:$PATH" USER=test-user SURFACE_SETUP_TESTING=1 \
    SURFACE_SETUP_FACE_STATE_FILE="$temp/$label.ledger" SURFACE_SETUP_BACKUP_ROOT="$temp/$label.backups" \
    SURFACE_SETUP_BACKUP_ID="$label" SURFACE_SETUP_TARGET_ROOT="$root" \
    bash "$root/modules/face-auth/scripts/run-face-setup.sh" $selection >"$temp/$label.out" 2>&1
  local rc=$?
  set -e
  assert_eq "$rc" "$expected_rc" "$label exit code"
  assert_eq "$(tr '\n' ' ' < "$log" | sed 's/ $//')" "$expected_log" "$label sequence"
  if [[ -n $selection && $label != no-camera ]]; then
    local ledger="$temp/$label.ledger"
    [[ -s "$ledger" ]] || fail "$label did not create the transaction ledger before setup"
    [[ -f "$temp/$label.backups/$label/.created_paths" && -f "$temp/$label.backups/$label/.backed_up_paths" ]] || fail "$label did not initialize both snapshot indexes"
    assert_eq "$(cat "$temp/$label.backups/$label/.surface_module")" face-auth "$label snapshot module label"
    local expected_status=installing
    [[ $expected_rc -eq 0 ]] && expected_status=installed
    assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$ledger")" "$expected_status" "$label ledger status"
  fi
}

run_case no-selection "" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 2 ""
run_case sudo-only "--sudo" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 0 "howdy sudo"
run_case polkit-only "--polkit" "camera=1 howdy=1 lock=0 password=1 sudo=0 polkit=0" 0 "polkit"
run_case lock-and-sudo "--lock --sudo" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 0 "howdy lock sudo"
run_case lock-only "--lock" "camera=1 howdy=1 lock=0 password=1 sudo=0 polkit=0" 0 "lock"
run_case sudo-and-polkit "--sudo --polkit" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 0 "howdy sudo polkit"
run_case all-three "--lock --sudo --polkit" "camera=1 howdy=1 lock=0 password=1 sudo=0 polkit=0" 0 "lock sudo polkit"
TEST_DELAY_READY=1 run_case delayed-lock-ready "--lock" "camera=1 howdy=1 lock=0 password=1 sudo=0 polkit=0" 0 "lock"
run_case lock-no-password "--lock" "camera=1 howdy=1 lock=0 password=0 sudo=0 polkit=0" 1 "lock"
run_case no-camera "--lock" "camera=0 howdy=0 lock=0 password=1 sudo=0 polkit=0" 1 ""
run_case stop-after-failure "--lock --sudo" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 9 "howdy" howdy

dispatch="$temp/dispatch/modules/face-auth/scripts"
mkdir -p "$dispatch"
cp "$repo_root/modules/face-auth/scripts/install-face.sh" "$dispatch/"
printf '#!/usr/bin/env bash\necho base >> "$TEST_LOG"\n' > "$dispatch/install-howdy-base.sh"
printf '#!/usr/bin/env bash\necho lock >> "$TEST_LOG"\n' > "$dispatch/install-lock-face.sh"
chmod +x "$dispatch"/*.sh
for args in "--base-only:base" "--lock-only:lock" ":base lock"; do
  mode=${args%%:*}; expected=${args#*:}; : > "$temp/dispatch.log"
  read -r -a mode_args <<<"$mode"
  TEST_LOG="$temp/dispatch.log" bash "$dispatch/install-face.sh" "${mode_args[@]}"
  assert_eq "$(tr '\n' ' ' < "$temp/dispatch.log" | sed 's/ $//')" "$expected" "face installer dispatch $mode"
done

printf 'Face setup runner tests passed.\n'
