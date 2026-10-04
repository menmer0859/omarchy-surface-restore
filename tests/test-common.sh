#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/scripts/common.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

source_file="$tmp/config.ini"
printf 'original\n' > "$source_file"
backup_dest=$(SURFACE_SETUP_BACKUP_ROOT="$tmp/backups" backup_path "$source_file")

backup=$(find "$tmp/backups" -type f -name config.ini -print -quit)
[[ -n "$backup" ]] || { echo 'backup_file did not create a backup' >&2; exit 1; }
cmp -s "$source_file" "$backup" || { echo 'backup content differs from source' >&2; exit 1; }
[[ "$backup_dest" == "$backup" ]] || { echo 'backup_path returned the wrong destination' >&2; exit 1; }

if (SURFACE_SETUP_BACKUP_ROOT="$tmp/backups" backup_path "$tmp/missing.ini") 2>/dev/null; then
  echo 'backup_path accepted a missing input' >&2
  exit 1
fi

echo 'common shell tests passed'
