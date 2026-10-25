#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -m 0700 "$stage/runtime"
ln -s /usr/share/omarchy/shell/Commons "$stage/Commons"
ln -s /usr/share/omarchy/shell/Ui "$stage/Ui"
ln -s "$root/modules/face-auth/assets" "$stage/assets"
cat > "$stage/shell.qml" <<'QML'
//@ pragma OmarchyLoadPatch
import QtQuick
import Quickshell
ShellRoot {
 Timer {
  running: true; interval: 100
  onTriggered: {
   var paths = ["assets/omarchy-lock/Service.qml", "assets/omarchy-polkit/PolkitAgent.qml"]
   for (var i=0; i<paths.length; i++) {
    var c = Qt.createComponent(paths[i]);
    if (c.status !== Component.Ready) { console.error("FAIL: " + c.errorString()); Qt.exit(1); return }
   }
   // Compile only: do not instantiate lock, PAM or PolkitAgent objects.
   console.log("SURFACE_SERVICES_COMPILE_PASS"); Qt.quit()
  }
 }
}
QML
# Load the Wayland type backend, without creating any windows/services.
[[ ${WAYLAND_DISPLAY:-} = /* ]] || export WAYLAND_DISPLAY="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY:-wayland-1}"
env QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=basic OMARCHY_PATH=/usr/share/omarchy XDG_RUNTIME_DIR="$stage/runtime" \
 timeout -k 3 20 quickshell -p "$stage/shell.qml" > "$stage/result.log" 2>&1 || { cat "$stage/result.log"; exit 1; }
cat "$stage/result.log"
grep -q 'SURFACE_SERVICES_COMPILE_PASS' "$stage/result.log"
! grep -Eq 'FAIL:|TypeError:|ReferenceError:|Cannot assign' "$stage/result.log"
