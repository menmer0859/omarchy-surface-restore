#!/usr/bin/env bash
# Compatibility shim for scripts that historically sourced scripts/common.sh.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/lib/common.sh"
