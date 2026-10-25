#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bootstrap="$repo_root/scripts/quick-install.sh"
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
export REAL_GIT
REAL_GIT=$(command -v git)
export LOCAL_GIT_REMOTE="file://$temp/remote.git"
"$REAL_GIT" init -q --bare --initial-branch=main "$temp/remote.git"
"$REAL_GIT" init -q --initial-branch=main "$temp/source"
write_installer() {
  cat > "$temp/source/install.sh" <<INSTALLER
#!/usr/bin/env bash
printf '%s\\n' "\$*" > "\$INSTALL_ARGS_FILE"
printf '%s\\n' '$1' > "\$INSTALL_VERSION_FILE"
INSTALLER
  chmod +x "$temp/source/install.sh"
  "$REAL_GIT" -C "$temp/source" add install.sh
  "$REAL_GIT" -C "$temp/source" -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm "$1"
  "$REAL_GIT" -C "$temp/source" push -q "$LOCAL_GIT_REMOTE" main
}
write_installer first
mkdir -p "$temp/bin"
cat > "$temp/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
if [[ ${1:-} == clone ]]; then
  [[ ${GIT_FAIL_CLONE:-0} != 1 ]] || exit 7
  for i in "${!args[@]}"; do
    if [[ ${args[$i]} == https://github.com/menmer0859/omarchy-surface-restore.git ]]; then
      args[$i]=$LOCAL_GIT_REMOTE
    fi
  done
  "$REAL_GIT" "${args[@]}"
  "$REAL_GIT" -C "${args[${#args[@]}-1]}" remote set-url origin https://github.com/menmer0859/omarchy-surface-restore.git
elif [[ ${1:-} == -C && ${3:-} == fetch ]]; then
  exec "$REAL_GIT" -C "$2" fetch "$LOCAL_GIT_REMOTE" main
else
  exec "$REAL_GIT" "$@"
fi
GIT
chmod +x "$temp/bin/git"
export INSTALL_ARGS_FILE="$temp/args" INSTALL_VERSION_FILE="$temp/version"
bootstrap_run() { HOME="$temp/home-first" PATH="$temp/bin:$PATH" bash "$bootstrap" "$@"; }
bootstrap_run face --lock --sudo
checkout="$temp/home-first/.local/share/omarchy-surface-restore"
[[ $(cat "$INSTALL_ARGS_FILE") == 'face --lock --sudo' ]] || fail 'installer arguments were not forwarded'
[[ $(cat "$INSTALL_VERSION_FILE") == first ]] || fail 'first install did not use cloned source'

# Use real Git history to prove a clean older checkout advances to main.
write_installer second
bootstrap_run face --sudo --polkit
[[ $(cat "$INSTALL_VERSION_FILE") == second ]] || fail 'existing clean checkout ran the obsolete installer'
[[ $(cat "$INSTALL_ARGS_FILE") == 'face --sudo --polkit' ]] || fail 'selective arguments were lost on update'

if HOME="$temp/home-failed" GIT_FAIL_CLONE=1 PATH="$temp/bin:$PATH" bash "$bootstrap" face >"$temp/failed.log" 2>&1; then
  fail 'bootstrap ignored a failed clone'
fi
[[ ! -e "$temp/home-failed/.local/share/omarchy-surface-restore" ]] || fail 'failed clone left a poisoned checkout'
if compgen -G "$temp/home-failed/.local/share/omarchy-surface-restore.download.*" >/dev/null; then fail 'failed clone left staging data'; fi

mkdir -p "$temp/home-occupied/.local/share/omarchy-surface-restore"
if HOME="$temp/home-occupied" PATH="$temp/bin:$PATH" bash "$bootstrap" face >"$temp/occupied.log" 2>&1; then
  fail 'bootstrap accepted a non-project directory'
fi
printf 'local edit\n' >> "$checkout/install.sh"
if bootstrap_run face >"$temp/dirty.log" 2>&1; then fail 'bootstrap accepted local edits'; fi
"$REAL_GIT" -C "$checkout" checkout -- install.sh

# A clean worktree containing local commits must not be silently executed.
printf 'local commit\n' > "$checkout/local-file"
"$REAL_GIT" -C "$checkout" add local-file
"$REAL_GIT" -C "$checkout" -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm local
if bootstrap_run face >"$temp/diverged.log" 2>&1; then fail 'bootstrap accepted a local commit outside remote main'; fi
printf 'quick install bootstrap Git lifecycle tests passed\n'
