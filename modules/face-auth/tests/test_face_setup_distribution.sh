#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
guide="$repo_root/docs/face-setup-plugin-distribution.md"

grep -q 'omarchy plugin add https://github.com/' "$guide"
grep -q 'a direct `omarchy plugin add` target' "$guide"
grep -q 'catalog listing' "$guide"
grep -q 'omarchy plugin validate' "$repo_root/README.md"
grep -q 'omarchy plugin validate' "$repo_root/README.zh-CN.md"

export_dir=$(mktemp -d)
trap 'rm -rf -- "$export_dir"' EXIT
python3 "$repo_root/modules/face-auth/scripts/export-setup-plugin.py" --output "$export_dir/plugin"
python3 - "$export_dir/plugin/manifest.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)
assert manifest["id"] == "surface.face-setup"
assert manifest["entryPoints"]["barWidget"] == "Panel.qml"
PY

if find "$export_dir/plugin" -type l -print -quit | grep -q .; then
  echo 'plugin export unexpectedly contains a symlink' >&2
  exit 1
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$export_dir/plugin"
fi

echo 'face setup plugin distribution checks passed'
