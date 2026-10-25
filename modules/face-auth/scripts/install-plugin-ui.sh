#!/usr/bin/env bash
set -euo pipefail
module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(cd "$module_root/../.." && pwd)
source "$root/lib/common.sh"
require_omarchy
require_face_ui_api
require_commands python3 omarchy-shell
[[ $# -eq 0 || ( $# -eq 1 && $1 == --check ) ]] || die 'Usage: install-plugin-ui.sh [--check]'
plugins_root="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
# Select only the previously installed face-capable clones, never stock lock or
# unrelated third-party code. Conflicts are rejected before the first backup.
targets=$(python3 - "$plugins_root" <<'PY'
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
found = {}
for path in root.glob('*/manifest.json'):
    if path.parent.name.startswith('.'):
        continue
    try:
        data = json.loads(path.read_text())
        meta = data.get('omarchy') or {}
    except (OSError, ValueError):
        continue
    source = meta.get('clonedFrom')
    if source not in ('omarchy.lock', 'omarchy.polkit'): continue
    kind = source.split('.')[-1]
    if kind in found: raise SystemExit('Conflicting ' + kind + ' clones; resolve them before upgrading.')
    if kind == 'lock' and not (path.parent/'FaceAttemptPolicy.js').is_file():
        raise SystemExit('Existing lock is not the Surface face plugin: ' + str(path.parent))
    if kind == 'polkit' and meta.get('surfaceFaceAuth') is not True:
        raise SystemExit('Existing Polkit clone is not managed by Surface setup: ' + str(path.parent))
    if '\n' in str(path.parent) or '\t' in str(path.parent): raise SystemExit('Unsupported plugin path')
    found[kind] = path.parent
if not found: raise SystemExit('No installed face plugins found. Configure face/polkit-face first.')
for kind, target in found.items(): print(kind + '\t' + str(target))
PY
) || die 'Could not safely select installed plugins.'
while IFS=$'\t' read -r kind target; do
  python3 "$module_root/scripts/deploy-face-ui.py" "$kind" "$target" --check
  printf 'Update %s UI: %s\n' "$kind" "$target"
done <<< "$targets"
[[ ${1:-} != --check ]] || exit 0
locked=$(omarchy-shell lock isLocked 2>/dev/null) || die 'Could not confirm lock state. Unlock the desktop before upgrading.'
[[ "$locked" == false ]] || die 'Unlock the desktop before upgrading its authentication plugins.'
printf 'This updates user plugin UI files only. PAM and Howdy configuration are unchanged.\n'
ask_yes_no 'Install the bilingual plugin UI?' || die 'Stopped before making changes.'
while IFS=$'\t' read -r kind target; do
  backup_and_report "$target"
  install_face_ui_resources "$kind" "$target"
  python3 - "$target/manifest.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1]); data = json.loads(path.read_text())
data['version'] = '2.1.0'
data['omarchy']['surfaceFaceAuth'] = True
path.write_text(json.dumps(data, indent=2) + '\n')
PY
done <<< "$targets"
info 'Bilingual plugin files installed. Close authorization dialogs, then run: omarchy restart shell'
info 'Restore the saved snapshot with ./scripts/restore.sh if needed.'
