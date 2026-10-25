#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
  cat <<'USAGE'
Usage: ./uninstall.sh face

Removes the face-authentication integrations recorded by ./install.sh face.
The enrolled model is retained in the protected transaction backup.
Touchscreen support is managed separately with the touch module.
USAGE
}

case "${1:-}" in
  face)
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    exec bash "$root/modules/face-auth/scripts/uninstall-face-auth.sh"
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
