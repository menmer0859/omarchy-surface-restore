#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root/lib/common.sh"

usage() {
  cat <<'EOF_USAGE'
Usage: ./install.sh [touch|face [--all|--lock --sudo --polkit]|sudo-face|polkit-face|plugin-ui|all|check]

Install one module independently:
  touch       Restore Surface touchscreen support (linux-surface + iptsd)
  face        Guided one-command IR face setup; select lock, sudo, and Polkit
  sudo-face   Optional consent-gated terminal sudo face authentication
  polkit-face Optional consent-gated graphical admin authentication
  plugin-ui   Upgrade installed face UI without changing PAM or Howdy
  all         Legacy behavior: touch followed by initial face setup
  check       Read-only compatibility summary

With no argument, an interactive module selection is shown. Review each
module's README and installer prompt before allowing system changes.
EOF_USAGE
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
if [[ -n "$action" ]]; then shift; fi
if [[ -z "$action" ]]; then
  cat <<'EOF_MENU'
Choose a module or optional face-authentication path:
  1) Restore touchscreen support
  2) Guided face setup (choose lock-screen, terminal sudo, and/or graphical authorization)
  3) Enable consent-gated face authentication for terminal sudo
  4) Enable consent-gated face authentication for graphical admin prompts
  5) Install both modules (legacy touch + initial face behavior)
  6) Read-only compatibility check
  7) Exit
EOF_MENU
  read -r -p 'Selection [1-7]: ' selection
  case "$selection" in
    1) action=touch ;;
    2) action=face ;;
    3) action=sudo-face ;;
    4) action=polkit-face ;;
    5) action=all ;;
    6) action=check ;;
    *) exit 0 ;;
  esac
fi

case "$action" in
  -h|--help|help) usage ;;
  check) check_system ;;
  touch) exec "$root/modules/touch/install.sh" ;;
  face|sudo-face|polkit-face|plugin-ui) exec "$root/modules/face-auth/install.sh" "$action" "$@" ;;
  all)
    "$root/modules/touch/install.sh"
    "$root/modules/face-auth/install.sh" face
    ;;
  *) usage >&2; exit 2 ;;
esac
