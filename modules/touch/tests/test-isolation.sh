#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
installer="$repo_root/modules/touch/install.sh"
grep -q 'linux-surface-headers iptsd' "$installer"
if grep -Eiq 'howdy|pam_howdy|polkit|omarchy-lock-face' "$installer"; then
  echo 'touch module must not configure face authentication' >&2
  exit 1
fi
[[ -x "$repo_root/modules/face-auth/install.sh" ]]
if grep -Eiq 'linux-surface|iptsd' "$repo_root/modules/face-auth/scripts/install-face.sh"; then
  echo 'face module must not configure touchscreen packages' >&2
  exit 1
fi
printf 'touch module isolation checks passed\n'
