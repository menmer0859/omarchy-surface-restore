#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/bin"
export PLUGIN_DISCOVERY_STATE="$temp/state"
cat > "$temp/bin/omarchy-shell" <<'IPC'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == 'shell rescanPlugins' ]]; then exit 0; fi
[[ "$*" == 'shell listPlugins' ]]
n=$(cat "$PLUGIN_DISCOVERY_STATE" 2>/dev/null || printf 0)
n=$((n + 1)); printf '%s\n' "$n" > "$PLUGIN_DISCOVERY_STATE"
if ((n < 3)); then printf '[]\n'; else printf '[{"id":"surface.lock","enabled":false}]\n'; fi
IPC
cat > "$temp/bin/omarchy" <<'ENABLE'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'plugin enable surface.lock' ]]
[[ $(cat "$PLUGIN_DISCOVERY_STATE") -ge 3 ]]
touch "$PLUGIN_DISCOVERY_STATE.enabled"
ENABLE
chmod +x "$temp/bin"/*
PATH="$temp/bin:$PATH" bash -c 'source "$1/lib/common.sh"; enable_face_plugin surface.lock' _ "$repo_root"
[[ -f $PLUGIN_DISCOVERY_STATE.enabled ]] || { printf 'FAIL: plugin was not enabled after discovery\n' >&2; exit 1; }
printf 'plugin discovery ordering tests passed\n'
