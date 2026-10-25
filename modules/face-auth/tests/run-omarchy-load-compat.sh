#!/usr/bin/env bash
set -euo pipefail

# Exercise the real Qt 6.12 name collision, including a plugin outside the shell
# config root. Never launch Omarchy services, PAM, or windows.
binary=${1:-quickshell}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/config/Commons" "$stage/external" "$stage/runtime"
chmod 0700 "$stage/runtime"
cat > "$stage/config/Commons/qmldir" <<'QML'
module qs.Commons
singleton Color 1.0 Color.qml
QML
cat > "$stage/config/Commons/Color.qml" <<'QML'
pragma Singleton
import QtQuick 6.11
QtObject {
  readonly property color accent: "#7aa2f7"
  readonly property QtObject polkit: QtObject {
    readonly property color background: "#1a1b26"
  }
}
QML
cat > "$stage/config/Probe.qml" <<'QML'
import QtQuick
import qs.Commons
QtObject {
  readonly property var observedAccent: Color.accent
  readonly property var observedPolkit: Color.polkit
}
QML
cp "$stage/config/Probe.qml" "$stage/external/Probe.qml"
cat > "$stage/config/shell.qml" <<'QML'
//@ pragma OmarchyLoadPatch
import QtQuick
import Quickshell
import qs.Commons as Commons
ShellRoot {
  Timer {
    running: true; interval: 100
    onTriggered: {
      const paths = [Qt.resolvedUrl("Probe.qml"), "file://" + Quickshell.env("SURFACE_EXTERNAL_PROBE")];
      for (const path of paths) {
        const component = Qt.createComponent(path);
        if (component.status !== Component.Ready) {
          console.error(component.errorString()); Qt.exit(1); return;
        }
        const probe = component.createObject(null);
        if (!probe || probe.observedAccent === undefined || !probe.observedPolkit
            || String(probe.observedAccent) !== "#7aa2f7"
            || String(probe.observedPolkit.background) !== "#1a1b26") {
          console.error("OMARCHY_COLOR_COLLISION", path, probe ? probe.observedAccent : "no object");
          Qt.exit(1); return;
        }
        probe.destroy();
      }
      console.log("OMARCHY_LOAD_COMPAT_PASS"); Qt.quit();
    }
  }
}
QML
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=basic \
  XDG_RUNTIME_DIR="$stage/runtime" SURFACE_EXTERNAL_PROBE="$stage/external/Probe.qml" \
  timeout -k 3 20 "$binary" -p "$stage/config/shell.qml" \
  > "$stage/result.log" 2>&1 || { cat "$stage/result.log"; exit 1; }
cat "$stage/result.log"
rg -q 'OMARCHY_LOAD_COMPAT_PASS' "$stage/result.log"
if rg -q 'Unrecognized pragma|OMARCHY_COLOR_COLLISION' "$stage/result.log"; then exit 1; fi
