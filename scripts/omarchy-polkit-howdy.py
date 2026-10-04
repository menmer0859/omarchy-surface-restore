#!/usr/bin/python
"""Run Howdy's matcher for the selected PAM account without protocol output."""

from __future__ import annotations

import os
import pwd


COMPARE = "/usr/lib/howdy/compare.py"


def command_for_user(username: str) -> list[str]:
    if not username:
        raise ValueError("PAM_USER is empty")
    pwd.getpwnam(username)
    return ["/usr/bin/python", COMPARE, username]


def main() -> int:
    try:
        command = command_for_user(os.environ.get("PAM_USER", ""))
    except (KeyError, ValueError):
        return 1
    os.execv(command[0], command)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
