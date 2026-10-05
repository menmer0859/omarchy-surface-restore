#!/usr/bin/env python3
"""Reject a second user plugin cloned from Omarchy's lock plugin."""

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: check-lock-plugin-clones.py PLUGINS_ROOT ALLOWED_PLUGIN", file=sys.stderr)
        return 2

    plugins_root = Path(sys.argv[1])
    allowed_plugin = Path(sys.argv[2]).resolve()
    if not plugins_root.is_dir():
        return 0

    for manifest in sorted(plugins_root.glob("*/manifest.json")):
        if manifest.parent.resolve() == allowed_plugin:
            continue
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict):
            continue
        metadata = data.get("omarchy")
        if isinstance(metadata, dict) and metadata.get("clonedFrom") == "omarchy.lock":
            print(f"Another Omarchy lock clone is installed at {manifest.parent}.", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
