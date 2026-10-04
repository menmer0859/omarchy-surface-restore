#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
help_output=$("$repo_root/install.sh" --help)
grep -q 'touch|face|all|check' <<< "$help_output"

if "$repo_root/install.sh" unknown >/dev/null 2>&1; then
  echo 'installer accepted an unknown action' >&2
  exit 1
fi

echo 'installer smoke tests passed'
