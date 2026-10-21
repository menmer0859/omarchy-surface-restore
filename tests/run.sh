#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
export PYTHONDONTWRITEBYTECODE=1

node tests/test_lock_face_policy.js

for script in install.sh scripts/*.sh tests/*.sh; do
  bash -n "$script"
done
bash -n scripts/sudo-face-consent
python3 -m py_compile scripts/configure-sudo-pam.py
python3 -m py_compile scripts/configure-polkit-pam.py
python3 -m py_compile scripts/render-polkit-device-access.py
python3 -m py_compile scripts/check-lock-plugin-clones.py
python3 -m py_compile scripts/omarchy-polkit-howdy.py scripts/omarchy-face-auth-locale scripts/deploy-face-ui.py

module_dir=$(mktemp -d)
trap 'rm -rf -- "$module_dir"' EXIT
read -r -a pam_flags <<<"$(pkg-config --cflags --libs pam)"
cc -shared -fPIC -Wall -Wextra -Werror "${pam_flags[@]}" \
  -o "$module_dir/pam_surface_face_consent.so" scripts/pam_surface_face_consent.c

bash tests/test-common.sh
bash tests/test-installer.sh
bash tests/test_restore_created_paths.sh
python3 -m unittest discover -s tests -p 'test_*.py'

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh scripts/*.sh tests/*.sh
else
  echo 'shellcheck not installed; skipped static analysis.'
fi

echo "Checking QML syntax..."
if command -v qmlformat >/dev/null 2>&1; then
  timeout 15 qmlformat assets/omarchy-lock/LockView.qml >/dev/null
  timeout 15 qmlformat assets/omarchy-lock/Service.qml >/dev/null
  timeout 15 qmlformat assets/omarchy-polkit/PolkitAgent.qml >/dev/null
elif [[ -x /usr/lib/qt6/bin/qmlformat ]]; then
  timeout 15 /usr/lib/qt6/bin/qmlformat assets/omarchy-lock/LockView.qml >/dev/null
  timeout 15 /usr/lib/qt6/bin/qmlformat assets/omarchy-lock/Service.qml >/dev/null
  timeout 15 /usr/lib/qt6/bin/qmlformat assets/omarchy-polkit/PolkitAgent.qml >/dev/null
else
  echo 'qmlformat not installed; skipped QML syntax check.'
fi

if [[ -r /usr/share/omarchy/shell/Commons/Translations.qml ]] && command -v quickshell >/dev/null 2>&1; then
  echo "Running native QML view tests..."
  bash tests/run-qml.sh
else
  echo 'Omarchy/Quickshell UI runtime unavailable; run tests/run-qml.sh on an Omarchy host.'
fi

echo 'All available checks passed.'
