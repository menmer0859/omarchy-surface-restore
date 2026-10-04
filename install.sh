#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage: ./install.sh [touch|face|all|check]

With no argument, an interactive menu is shown.
  touch  Install linux-surface kernel support and iptsd
  face   Configure Howdy and Omarchy lock-screen face/password switching
  all    Run both setup paths
  check  Read-only system compatibility summary

Review the scripts and README before running. This project changes system
packages and authentication configuration; it asks before applying changes.
EOF
}

check_system() {
  printf 'Omarchy: '
  if [[ -d /usr/share/omarchy ]] && command -v omarchy-shell >/dev/null 2>&1; then
    pacman -Q omarchy 2>/dev/null || printf 'detected (version unavailable)\n'
  else
    printf 'not detected\n'
  fi
  printf 'Surface hint: '
  if [[ -r /sys/devices/virtual/dmi/id/sys_vendor ]]; then
    printf '%s %s\n' "$(cat /sys/devices/virtual/dmi/id/sys_vendor)" "$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
  else
    printf 'unavailable\n'
  fi
  printf 'Running kernel: %s\n' "$(uname -r)"
  printf 'Stable video nodes:\n'
  if [[ -d /dev/v4l/by-path ]]; then
    find /dev/v4l/by-path -maxdepth 1 -type l -print | sort
  else
    printf '  none found at /dev/v4l/by-path\n'
  fi
}

action=${1:-}
if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi
if [[ -z "$action" ]]; then
  cat <<'EOF'
Choose a setup path:
  1) Restore touchscreen support
  2) Configure IR face unlock and password switching
  3) Do both
  4) Read-only compatibility check
  5) Exit
EOF
  read -r -p 'Selection [1-5]: ' selection
  case "$selection" in
    1) action=touch ;;
    2) action=face ;;
    3) action=all ;;
    4) action=check ;;
    *) exit 0 ;;
  esac
fi

case "$action" in
  -h|--help|help) usage ;;
  check) check_system ;;
  touch) exec "$root/scripts/install-touch.sh" ;;
  face) exec "$root/scripts/install-face.sh" ;;
  all)
    "$root/scripts/install-touch.sh"
    "$root/scripts/install-face.sh"
    ;;
  *) usage >&2; exit 2 ;;
esac
