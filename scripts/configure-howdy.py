#!/usr/bin/env python3
"""Set Howdy's selected camera while preserving unrelated config text."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def update_config(path: Path, device: str) -> None:
    text = path.read_text(encoding="utf-8")
    replacements = {
        "device_path": device,
        "frame_width": "480",
        "frame_height": "480",
    }
    for key, value in replacements.items():
        pattern = re.compile(rf"^(\s*{re.escape(key)}\s*=\s*).*$", re.MULTILINE)
        text, count = pattern.subn(lambda match: match.group(1) + value, text, count=1)
        if count != 1:
            raise ValueError(f"Expected exactly one {key} entry in {path}")
    path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: configure-howdy.py CONFIG_PATH DEVICE_PATH")
    config_path = Path(sys.argv[1])
    if not config_path.is_file():
        raise SystemExit(f"Howdy config does not exist: {config_path}")
    update_config(config_path, sys.argv[2])
