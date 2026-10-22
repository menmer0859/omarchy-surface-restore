#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/lib/common.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

source_file="$tmp/config.ini"
printf 'original\n' > "$source_file"
backup_dest=$(SURFACE_SETUP_BACKUP_ROOT="$tmp/backups" backup_path "$source_file")

backup=$(find "$tmp/backups" -type f -name config.ini -print -quit)
[[ -n "$backup" ]] || { echo 'backup_file did not create a backup' >&2; exit 1; }
cmp -s "$source_file" "$backup" || { echo 'backup content differs from source' >&2; exit 1; }
[[ "$backup_dest" == "$backup" ]] || { echo 'backup_path returned the wrong destination' >&2; exit 1; }
module_source="$tmp/module.ini"
printf 'module config\n' > "$module_source"
SURFACE_SETUP_BACKUP_ROOT="$tmp/module-backups" SURFACE_SETUP_BACKUP_ID=face-test SURFACE_SETUP_MODULE=face-auth \
  bash -c 'source "$1/lib/common.sh"; backup_path "$2" >/dev/null' _ "$repo_root" "$module_source"
[[ $(cat "$tmp/module-backups/face-test/.surface_module") == face-auth ]] || { echo 'new backup lacks its module label' >&2; exit 1; }

if (SURFACE_SETUP_BACKUP_ROOT="$tmp/backups" backup_path "$tmp/missing.ini") 2>/dev/null; then
  echo 'backup_path accepted a missing input' >&2
  exit 1
fi

echo 'common shell tests passed'
