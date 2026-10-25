#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mode=${1:-full}
case "$mode" in
  --base-only)
    [[ $# -eq 1 ]] || { echo 'Usage: install-face.sh [--base-only|--lock-only]' >&2; exit 2; }
    exec "$module_root/scripts/install-howdy-base.sh"
    ;;
  --lock-only)
    [[ $# -eq 1 ]] || { echo 'Usage: install-face.sh [--base-only|--lock-only]' >&2; exit 2; }
    exec "$module_root/scripts/install-lock-face.sh"
    ;;
  full)
    [[ $# -eq 0 ]] || { echo 'Usage: install-face.sh [--base-only|--lock-only]' >&2; exit 2; }
    "$module_root/scripts/install-howdy-base.sh"
    exec "$module_root/scripts/install-lock-face.sh"
    ;;
  *)
    echo 'Usage: install-face.sh [--base-only|--lock-only]' >&2
    exit 2
    ;;
esac
