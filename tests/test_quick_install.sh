#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bootstrap="$repo_root/scripts/quick-install.sh"
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$temp/bin" "$temp/fixture"
cat > "$temp/fixture/install.sh" <<'INSTALLER'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$INSTALL_ARGS_FILE"
INSTALLER
chmod +x "$temp/fixture/install.sh"

cat > "$temp/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == clone ]]; then
  [[ ${GIT_FAIL_CLONE:-0} != 1 ]] || exit 7
  source_dir=${GIT_FIXTURE_SOURCE:?}
  target=${@: -1}
  mkdir -p "$target/.git"
  cp "$source_dir/install.sh" "$target/install.sh"
  printf '%s\n' https://github.com/menmer0859/omarchy-surface-restore.git > "$target/.git/remote-origin"
elif [[ ${1:-} == -C && ${3:-} == remote && ${4:-} == get-url && ${5:-} == origin ]]; then
  cat "$2/.git/remote-origin"
elif [[ ${1:-} == -C && ${3:-} == status && ${4:-} == --porcelain ]]; then
  [[ ! -e "$2/.git/dirty" ]] || printf ' M install.sh\n'
else
  printf 'unexpected git call: %s\n' "$*" >&2
  exit 2
fi
GIT
chmod +x "$temp/bin/git"

# A first run clones into the stable location so uninstall remains available.
HOME="$temp/home-first" INSTALL_ARGS_FILE="$temp/first.args" GIT_FIXTURE_SOURCE="$temp/fixture" \
  PATH="$temp/bin:$PATH" bash "$bootstrap" face --lock --sudo
target="$temp/home-first/.local/share/omarchy-surface-restore"
[[ -f $target/install.sh ]] || fail 'first install did not retain the project checkout'
[[ $(cat "$temp/first.args") == 'face --lock --sudo' ]] || fail 'installer arguments were not forwarded'

# A failed clone is cleaned from the staging area, so the next run can retry.
if HOME="$temp/home-failed" GIT_FAIL_CLONE=1 INSTALL_ARGS_FILE="$temp/failed.args" GIT_FIXTURE_SOURCE="$temp/fixture" \
  PATH="$temp/bin:$PATH" bash "$bootstrap" face >"$temp/failed.log" 2>&1; then
  fail 'bootstrap ignored a failed clone'
fi
[[ ! -e "$temp/home-failed/.local/share/omarchy-surface-restore" ]] || fail 'failed clone left a poisoned checkout path'
if compgen -G "$temp/home-failed/.local/share/omarchy-surface-restore.download.*" >/dev/null; then
  fail 'failed clone left temporary staging data'
fi

# A clean existing project checkout is reused without an update or reclone.
HOME="$temp/home-first" INSTALL_ARGS_FILE="$temp/reuse.args" GIT_FIXTURE_SOURCE="$temp/fixture" \
  PATH="$temp/bin:$PATH" bash "$bootstrap" face --all
[[ $(cat "$temp/reuse.args") == 'face --all' ]] || fail 'existing checkout was not reused'

# Existing user data and dirty checkouts are never overwritten or executed.
mkdir -p "$temp/home-occupied/.local/share/omarchy-surface-restore"
if HOME="$temp/home-occupied" INSTALL_ARGS_FILE="$temp/occupied.args" GIT_FIXTURE_SOURCE="$temp/fixture" \
  PATH="$temp/bin:$PATH" bash "$bootstrap" face >"$temp/occupied.log" 2>&1; then
  fail 'bootstrap accepted a non-project target directory'
fi
[[ ! -e $temp/occupied.args ]] || fail 'bootstrap ran an installer from a rejected target'

touch "$target/.git/dirty"
if HOME="$temp/home-first" INSTALL_ARGS_FILE="$temp/dirty.args" GIT_FIXTURE_SOURCE="$temp/fixture" \
  PATH="$temp/bin:$PATH" bash "$bootstrap" face >"$temp/dirty.log" 2>&1; then
  fail 'bootstrap accepted a modified checkout'
fi
[[ ! -e $temp/dirty.args ]] || fail 'bootstrap ran an installer from a modified checkout'

echo 'quick install bootstrap tests passed'
