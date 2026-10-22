#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -m 0700 "$stage/runtime"
ln -s /usr/share/omarchy/shell/Commons "$stage/Commons"
ln -s /usr/share/omarchy/shell/Ui "$stage/Ui"
ln -s "$root/assets" "$stage/assets"
cp "$root/tests/qml/polkit-return.qml" "$stage/shell.qml"
env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic \
 QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$stage/runtime" \
 OMARCHY_PATH=/usr/share/omarchy OMARCHY_LANGUAGE_FILE="$stage/language" \
 timeout -k 3 25 quickshell -p "$stage/shell.qml" >"$stage/result.log" 2>&1 || { cat "$stage/result.log"; exit 1; }
cat "$stage/result.log"
grep -q 'POLKIT_RETURN_QML_PASS' "$stage/result.log"
if grep -E 'FAIL:|TypeError:|ReferenceError:|Cannot assign|is not a type|unavailable|Binding loop' "$stage/result.log"; then exit 1; fi
