#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
export PYTHONDONTWRITEBYTECODE=1

for script in install.sh scripts/*.sh tests/*.sh; do
  bash -n "$script"
done
bash -n scripts/sudo-face-consent
python3 -m py_compile scripts/configure-sudo-pam.py

bash tests/test-common.sh
bash tests/test-installer.sh
python3 -m unittest discover -s tests -p 'test_*.py'

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh scripts/*.sh tests/*.sh
else
  echo 'shellcheck not installed; skipped static analysis.'
fi

if command -v qmlformat >/dev/null 2>&1; then
  qmlformat assets/omarchy-lock/LockView.qml >/dev/null
  qmlformat assets/omarchy-lock/Service.qml >/dev/null
elif [[ -x /usr/lib/qt6/bin/qmlformat ]]; then
  /usr/lib/qt6/bin/qmlformat assets/omarchy-lock/LockView.qml >/dev/null
  /usr/lib/qt6/bin/qmlformat assets/omarchy-lock/Service.qml >/dev/null
else
  echo 'qmlformat not installed; skipped QML syntax check.'
fi

echo 'All available checks passed.'
