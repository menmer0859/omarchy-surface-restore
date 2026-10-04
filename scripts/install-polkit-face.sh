#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/common.sh"
require_omarchy
require_commands sudo python3 install cc pkg-config omarchy jq readlink systemctl

service=/etc/pam.d/polkit-1
vendor_service=/usr/lib/pam.d/polkit-1
system_auth=/etc/pam.d/system-auth
module=/usr/local/lib/security/pam_surface_face_consent.so
howdy_helper=/usr/local/libexec/omarchy-polkit-howdy
howdy_compare=/usr/lib/howdy/compare.py
howdy_config=/etc/howdy/config.ini
device_dropin=/etc/systemd/system/polkit-agent-helper@.service.d/60-omarchy-surface-face.conf
clone_user=${USER:-$(id -un)}
plugin_root="$HOME/.config/omarchy/plugins/$clone_user.polkit"
plugin_manifest="$plugin_root/manifest.json"
plugin_qml="$plugin_root/PolkitAgent.qml"
plugin_model="$plugin_root/PolkitModel.js"
plugins_root="$HOME/.config/omarchy/plugins"
model="/etc/howdy/models/$clone_user.dat"
module_tmp=$(mktemp "${TMPDIR:-/tmp}/pam_surface_face_consent.XXXXXX.so")
dropin_tmp=$(mktemp "${TMPDIR:-/tmp}/polkit-surface-camera.XXXXXX.conf")
trap 'rm -f -- "$module_tmp" "$dropin_tmp"' EXIT
plugin_existing=0

command -v howdy >/dev/null 2>&1 || die 'Howdy is not installed. Configure face authentication and enroll a model first.'
[[ -s "$model" ]] || die "No Howdy model found for $clone_user at $model. Enroll this account before enabling Polkit face auth."
[[ -r "$howdy_compare" ]] || die "Howdy's comparison program is missing at $howdy_compare."
[[ -r /usr/lib/security/pam_faillock.so ]] || die 'pam_faillock.so is missing.'
[[ -r "$system_auth" ]] || die "The expected PAM stack is missing: $system_auth"
[[ -r "$vendor_service" ]] || die "The vendor Polkit PAM service is missing: $vendor_service"
[[ -r "$howdy_config" ]] || die "Howdy configuration is missing at $howdy_config."
camera_path=$(python3 - "$howdy_config" <<'PY'
import configparser
import sys

config = configparser.ConfigParser()
if not config.read(sys.argv[1]) or not config.has_option("video", "device_path"):
    raise SystemExit("Howdy config has no [video] device_path")
print(config.get("video", "device_path"))
PY
) || die 'Could not read the camera device from Howdy configuration.'
camera_device=$(readlink -f -- "$camera_path") || die "Howdy camera path does not resolve: $camera_path"
[[ "$camera_device" =~ ^/dev/video[0-9]+$ && -c "$camera_device" ]] \
  || die "Howdy camera path must resolve to a video character device; got $camera_device."
python3 "$root/scripts/render-polkit-device-access.py" "$camera_device" > "$dropin_tmp"
pkg-config --exists pam || die 'PAM development files are missing; install the linux-pam headers and pkgconf.'

if [[ -e "$service" || -L "$service" ]]; then
  [[ -f "$service" && ! -L "$service" ]] || die "Refusing to replace non-regular Polkit PAM path: $service"
  service_source=$service
else
  service_source=$vendor_service
fi
python3 "$root/scripts/configure-polkit-pam.py" "$service_source" "$system_auth" --check >/dev/null \
  || die 'The current Polkit PAM stack is not in the expected form; no changes have been made.'

if [[ -d "$plugin_root" ]]; then
  python3 - "$plugin_manifest" <<'PY' || die "A Polkit plugin already exists at $plugin_root and is not managed by this installer. Review it before continuing."
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)
omarchy = data.get("omarchy", {})
raise SystemExit(0 if omarchy.get("clonedFrom") == "omarchy.polkit" and omarchy.get("surfaceFaceAuth") is True else 1)
PY
  plugin_existing=1
elif [[ -e "$plugin_root" || -L "$plugin_root" ]]; then
  die "Refusing to use an incomplete plugin path: $plugin_root"
fi

if [[ -d "$plugins_root" ]]; then
  conflict=$(python3 - "$plugins_root" "$plugin_root" <<'PY'
import json
import sys
from pathlib import Path

plugins, allowed = map(Path, sys.argv[1:])
for manifest in plugins.glob("*/manifest.json"):
    if manifest.parent == allowed:
        continue
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        continue
    if data.get("omarchy", {}).get("clonedFrom") == "omarchy.polkit":
        print(manifest.parent)
        break
PY
)
  [[ -z "$conflict" ]] || die "Another Polkit plugin clone is active at $conflict. Resolve it before installing this clone."
fi

printf 'This optional setup adds two buttons to Omarchy\x27s fullscreen Polkit dialog.\n'
printf 'The camera starts only after clicking “Use face”; decline, timeout, or failed recognition returns to password authentication.\n'
printf 'It changes the Omarchy user Polkit plugin, %s, %s, %s, and a systemd device rule for %s.\n\n' "$service" "$module" "$howdy_helper" "$camera_device"
ask_yes_no 'Enable consent-gated face authentication for graphical Polkit requests?' || die 'Stopped before making changes.'
sudo -v

if (( plugin_existing )); then
  backup_and_report "$plugin_root"
fi

if [[ -e "$service" ]]; then
  backup_and_report "$service"
else
  mark_new_path "$service"
fi
if [[ -e "$module" ]]; then
  backup_and_report "$module"
else
  mark_new_path "$module"
fi
if [[ -e "$howdy_helper" ]]; then
  backup_and_report "$howdy_helper"
else
  mark_new_path "$howdy_helper"
fi
if [[ -e "$device_dropin" ]]; then
  backup_and_report "$device_dropin"
else
  device_dropin_dir=$(dirname "$device_dropin")
  [[ -d "$device_dropin_dir" ]] || mark_new_path "$device_dropin_dir"
  mark_new_path "$device_dropin"
fi

if [[ ! -d "$plugin_root" ]]; then
  mark_new_path "$plugin_manifest"
  mark_new_path "$plugin_qml"
  mark_new_path "$plugin_model"
  omarchy plugin clone omarchy.polkit
  [[ -d "$plugin_root" ]] || die "Omarchy did not create the expected clone at $plugin_root."
fi

read -r -a pam_flags <<<"$(pkg-config --cflags --libs pam)"
cc -shared -fPIC -Wall -Wextra -Werror "${pam_flags[@]}" \
  -o "$module_tmp" "$root/scripts/pam_surface_face_consent.c"
sudo install -D -o root -g root -m 0644 "$module_tmp" "$module"
sudo install -D -o root -g root -m 0755 "$root/scripts/omarchy-polkit-howdy.py" "$howdy_helper"
install -m 0644 "$root/assets/omarchy-polkit/PolkitAgent.qml" "$plugin_qml"
install -m 0644 "$root/assets/omarchy-polkit/PolkitModel.js" "$plugin_model"
python3 - "$plugin_manifest" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
omarchy = data.setdefault("omarchy", {})
if omarchy.get("clonedFrom") != "omarchy.polkit":
    raise SystemExit("refusing to label a plugin that is not cloned from omarchy.polkit")
omarchy["surfaceFaceAuth"] = True
data["version"] = "1.1.0"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
omarchy-shell shell rescanPlugins >/dev/null

if [[ ! -e "$service" ]]; then
  sudo install -D -o root -g root -m 0644 "$vendor_service" "$service"
fi
sudo python3 "$root/scripts/configure-polkit-pam.py" "$service" "$system_auth"
sudo install -D -o root -g root -m 0644 "$dropin_tmp" "$device_dropin"
sudo systemctl daemon-reload

[[ $(sudo stat -c '%U:%G:%a' "$module") == root:root:644 ]] || die 'The Polkit PAM module is not root-owned mode 0644.'
[[ $(sudo stat -c '%U:%G:%a' "$howdy_helper") == root:root:755 ]] || die 'The Polkit Howdy helper is not root-owned mode 0755.'
sudo grep -qF "$module" "$service" || die 'The Polkit PAM file was not updated as expected.'
sudo grep -qF "DeviceAllow=$camera_device rw" "$device_dropin" || die 'The Polkit helper camera permission was not installed as expected.'
info 'Consent-gated face authentication is enabled for graphical Polkit prompts.'
printf 'Test with a graphical admin action, or run “pkexec /usr/bin/id”. Choose Use password first, then trigger it again and choose Use face.\n'
printf 'Keep this terminal open until both paths work. To remove the feature, restore the snapshot with ./scripts/restore.sh.\n'
