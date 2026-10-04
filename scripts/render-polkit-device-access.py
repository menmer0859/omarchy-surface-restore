#!/usr/bin/env python3
"""Render the narrow systemd device rule needed by the Polkit Howdy helper."""

import re
import sys


def main() -> int:
    if len(sys.argv) != 2 or re.fullmatch(r"/dev/video[0-9]+", sys.argv[1]) is None:
        print("expected a canonical /dev/videoN device path", file=sys.stderr)
        return 2

    print("[Service]")
    print("PrivateDevices=no")
    print(f"DeviceAllow={sys.argv[1]} rw")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
