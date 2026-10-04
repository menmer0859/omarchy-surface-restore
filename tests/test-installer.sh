#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
help_output=$("$repo_root/install.sh" --help)
grep -q 'touch|face|sudo-face|all|check' <<< "$help_output"
grep -q 'explicit-consent Howdy for terminal sudo' <<< "$help_output"
[[ -x "$repo_root/scripts/install-sudo-face.sh" ]]
grep -q 'sudo-face) exec' "$repo_root/install.sh"
menu_output=$(printf '6\n' | "$repo_root/install.sh")
grep -q '3) Enable consent-gated face authentication for sudo' <<< "$menu_output"

if "$repo_root/install.sh" unknown >/dev/null 2>&1; then
  echo 'installer accepted an unknown action' >&2
  exit 1
fi

echo 'installer smoke tests passed'
