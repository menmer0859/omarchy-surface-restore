#!/usr/bin/env bash
set -euo pipefail

# Downloaded with `curl | bash`; keep this bootstrap small and delegate all
# privileged work to the reviewed installer in a persistent clean checkout.
repository_url='https://github.com/menmer0859/omarchy-surface-restore.git'
expected_https='https://github.com/menmer0859/omarchy-surface-restore.git'
expected_ssh='git@github.com:menmer0859/omarchy-surface-restore.git'
checkout="${HOME:?HOME is required}/.local/share/omarchy-surface-restore"
stage_dir=''

cleanup() {
  [[ -z $stage_dir ]] || rm -rf -- "$stage_dir"
}
trap cleanup EXIT

fail() {
  printf 'quick-install: %s\n' "$*" >&2
  exit 1
}

[[ $(id -u) != 0 ]] || fail 'Run this installer as your normal desktop account, without sudo.'

command -v git >/dev/null 2>&1 || fail 'git is required. Install it, then rerun this command.'

if [[ -e $checkout || -L $checkout ]]; then
  [[ ! -L $checkout && -d $checkout/.git && -f $checkout/install.sh ]] \
    || fail "Refusing to overwrite a non-project path: $checkout"
  remote=$(git -C "$checkout" remote get-url origin 2>/dev/null) \
    || fail "Could not verify the existing checkout origin: $checkout"
  [[ $remote == "$expected_https" || $remote == "$expected_ssh" ]] \
    || fail "Existing checkout has an unexpected origin: $remote"
  working_tree=$(git -C "$checkout" status --porcelain --untracked-files=normal) \
    || fail "Could not inspect the existing checkout: $checkout"
  [[ -z $working_tree ]] \
    || fail "Existing checkout has local changes. Review it before using: $checkout"
  branch=$(git -C "$checkout" branch --show-current)
  [[ $branch == main ]] || fail "Existing checkout must be on main; review its current branch: $branch"
  git -C "$checkout" fetch origin main
  git -C "$checkout" merge-base --is-ancestor HEAD FETCH_HEAD \
    || fail 'Existing checkout has commits outside remote main; review them before installing.'
  git -C "$checkout" merge --ff-only FETCH_HEAD
else
  mkdir -p "$(dirname "$checkout")"
  stage_dir=$(mktemp -d "${checkout}.download.XXXXXX")
  git clone --depth 1 --branch main "$repository_url" "$stage_dir/repository"
  mv -- "$stage_dir/repository" "$checkout"
  rmdir -- "$stage_dir"
  stage_dir=''
fi

exec bash "$checkout/install.sh" "$@"
