#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
source_root=${1:?Usage: modules/face-auth/tests/run-polkit-native.sh /absolute/path/to/patched/quickshell-source}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
cmake -S "$root/modules/face-auth/tests/native/polkit-restart" -B "$stage" -G Ninja -DQUICKSHELL_SOURCE="$source_root"
cmake --build "$stage" -j 2
"$stage/polkit-restart"
