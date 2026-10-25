#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
export PYTHONDONTWRITEBYTECODE=1

node modules/face-auth/tests/test_lock_face_policy.js
node modules/face-auth/tests/test_display_wake_policy.js
node modules/face-auth/tests/test_lock_activity_policy.js
node modules/face-auth/tests/test_polkit_return.js
node modules/face-auth/tests/test-setup-model.js

for script in install.sh scripts/*.sh lib/*.sh modules/face-auth/install.sh modules/face-auth/scripts/*.sh modules/touch/install.sh modules/touch/tests/*.sh tests/*.sh modules/face-auth/tests/*.sh; do
  bash -n "$script"
done
bash -n modules/face-auth/scripts/sudo-face-consent
python3 -m py_compile modules/face-auth/scripts/configure-sudo-pam.py
python3 -m py_compile modules/face-auth/scripts/configure-polkit-pam.py
python3 -m py_compile modules/face-auth/scripts/render-polkit-device-access.py
python3 -m py_compile modules/face-auth/scripts/check-lock-plugin-clones.py
python3 -m py_compile modules/face-auth/scripts/omarchy-polkit-howdy.py modules/face-auth/scripts/omarchy-face-auth-locale modules/face-auth/scripts/deploy-face-ui.py
python3 -m py_compile modules/face-auth/scripts/export-setup-plugin.py modules/face-auth/scripts/face-setup-status.py

module_dir=$(mktemp -d)
trap 'rm -rf -- "$module_dir"' EXIT
read -r -a pam_flags <<<"$(pkg-config --cflags --libs pam)"
cc -shared -fPIC -Wall -Wextra -Werror "${pam_flags[@]}" \
  -o "$module_dir/pam_surface_face_consent.so" modules/face-auth/scripts/pam_surface_face_consent.c

bash tests/test-common.sh
bash tests/test-installer.sh
bash modules/touch/tests/test-isolation.sh
bash tests/test_restore_created_paths.sh
bash tests/test_module_restore_isolation.sh
bash modules/face-auth/tests/test_run_face_setup.sh
bash modules/face-auth/tests/test_face_setup_distribution.sh
python3 -m unittest discover -s modules/face-auth/tests -p 'test_*.py'

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh scripts/*.sh lib/*.sh modules/face-auth/install.sh modules/face-auth/scripts/*.sh modules/touch/install.sh modules/touch/tests/*.sh tests/*.sh modules/face-auth/tests/*.sh
else
  echo 'shellcheck not installed; skipped static analysis.'
fi

echo "Checking QML syntax..."
if command -v qmlformat >/dev/null 2>&1; then
  timeout 15 qmlformat modules/face-auth/assets/omarchy-lock/LockView.qml >/dev/null
  timeout 15 qmlformat modules/face-auth/assets/omarchy-lock/Service.qml >/dev/null
  timeout 15 qmlformat modules/face-auth/assets/omarchy-polkit/PolkitAgent.qml >/dev/null
  timeout 15 qmlformat modules/face-auth/assets/face-setup/Panel.qml >/dev/null
elif [[ -x /usr/lib/qt6/bin/qmlformat ]]; then
  timeout 15 /usr/lib/qt6/bin/qmlformat modules/face-auth/assets/omarchy-lock/LockView.qml >/dev/null
  timeout 15 /usr/lib/qt6/bin/qmlformat modules/face-auth/assets/omarchy-lock/Service.qml >/dev/null
  timeout 15 /usr/lib/qt6/bin/qmlformat modules/face-auth/assets/omarchy-polkit/PolkitAgent.qml >/dev/null
  timeout 15 /usr/lib/qt6/bin/qmlformat modules/face-auth/assets/face-setup/Panel.qml >/dev/null
else
  echo 'qmlformat not installed; skipped QML syntax check.'
fi

if [[ -r /usr/share/omarchy/shell/Commons/Translations.qml ]] && command -v quickshell >/dev/null 2>&1; then
  echo "Running native QML view tests..."
  bash modules/face-auth/tests/run-omarchy-load-compat.sh
  bash modules/face-auth/tests/run-qml.sh
  bash modules/face-auth/tests/run-polkit-qml.sh
else
  echo 'Omarchy/Quickshell UI runtime unavailable; run tests/run-qml.sh on an Omarchy host.'
fi

echo 'All available checks passed.'
