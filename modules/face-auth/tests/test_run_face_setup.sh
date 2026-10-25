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
  cat > "$root/modules/face-auth/scripts/face-setup-status.py" <<'PY'
import json, os
from pathlib import Path
state = dict(item.split("=", 1) for item in Path(os.environ["TEST_STATE_FILE"]).read_text().split())
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
  printf '%s\n' "$initial" > "$state"
  : > "$log"
  set +e
  # shellcheck disable=SC2086
  TEST_STATE_FILE="$state" TEST_LOG="$log" FAIL_AT="$fail_at" bash "$root/modules/face-auth/scripts/run-face-setup.sh" $selection >"$temp/$label.out" 2>&1
  local rc=$?
  set -e
  assert_eq "$rc" "$expected_rc" "$label exit code"
  assert_eq "$(tr '\n' ' ' < "$log" | sed 's/ $//')" "$expected_log" "$label sequence"
}

run_case no-selection "" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 2 ""
run_case sudo-only "--sudo" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 0 "howdy sudo"
run_case polkit-only "--polkit" "camera=1 howdy=1 lock=0 password=1 sudo=0 polkit=0" 0 "polkit"
run_case lock-and-sudo "--lock --sudo" "camera=1 howdy=0 lock=0 password=1 sudo=0 polkit=0" 0 "howdy lock sudo"
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
