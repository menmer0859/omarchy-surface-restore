#!/usr/bin/env python3
"""Safely add consent-gated Howdy authentication to one sudo PAM file."""

from __future__ import annotations

import argparse
import os
import re
import stat
import tempfile
from pathlib import Path


BEGIN = "# BEGIN omarchy-surface-restore sudo face authentication"
END = "# END omarchy-surface-restore sudo face authentication"
HELPER = "/usr/local/libexec/omarchy-sudo-face-consent"


def _faillock_options(system_auth: str, marker: str) -> str:
    found: list[list[str]] = []
    for line in system_auth.splitlines():
        fields = line.split()
        if len(fields) < 4 or fields[0] != "auth" or fields[2] != "pam_faillock.so":
            continue
        if marker in fields[3:]:
            found.append(fields)
    if len(found) != 1:
        raise ValueError(f"expected exactly one auth pam_faillock.so {marker} rule in system-auth")
    fields = found[0]
    if fields[1] not in {"required", "requisite", "sufficient", "optional"} and not fields[1].startswith("["):
        raise ValueError(f"unsupported PAM control for pam_faillock.so {marker}")
    options = [arg for arg in fields[3:] if arg != marker]
    return (" " + " ".join(options)) if options else ""


def render_sudo_pam(sudo_config: str, system_auth: str) -> str:
    preauth_options = _faillock_options(system_auth, "preauth")
    authsucc_options = _faillock_options(system_auth, "authsucc")

    lines = sudo_config.splitlines(keepends=True)
    managed = False
    clean: list[str] = []
    for line in lines:
        stripped = line.rstrip("\r\n")
        if stripped == BEGIN:
            if managed:
                raise ValueError("duplicate sudo face authentication markers")
            managed = True
            continue
        if stripped == END:
            if not managed:
                raise ValueError("unmatched sudo face authentication end marker")
            managed = False
            continue
        if not managed:
            clean.append(line)
    if managed:
        raise ValueError("unclosed sudo face authentication marker")

    base = "".join(clean)
    if re.search(r"^\s*auth\s+.*\bpam_howdy\.so\b", base, re.MULTILINE):
        raise ValueError("sudo PAM already has an unmanaged pam_howdy.so rule; refusing to duplicate it")

    include_matches = [
        re.match(r"^(\s*)auth(\s+)include(\s+)system-auth(\s*(?:#.*)?)?(\r?\n)?$", line)
        for line in clean
    ]
    positions = [index for index, match in enumerate(include_matches) if match]
    if len(positions) != 1:
        raise ValueError("expected exactly one auth include system-auth rule in sudo PAM")

    index = positions[0]
    match = include_matches[index]
    assert match is not None
    newline = match.group(5) or "\n"
    indent = match.group(1)
    rules = (
        f"{BEGIN}{newline}"
        f"{indent}auth requisite pam_faillock.so preauth{preauth_options}{newline}"
        f"{indent}auth [success=ok default=2] pam_exec.so quiet {HELPER}{newline}"
        f"{indent}auth [success=ok default=1] pam_howdy.so{newline}"
        f"{indent}auth [success=done default=die] pam_faillock.so authsucc{authsucc_options}{newline}"
        f"{END}{newline}"
    )
    clean[index:index] = [rules]
    return "".join(clean)


def _atomic_replace(path: Path, content: str) -> None:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"refusing to replace non-regular or symlink PAM path: {path}")
    metadata = path.stat()
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", newline="", dir=path.parent, prefix=f".{path.name}.", delete=False
        ) as stream:
            temporary_name = stream.name
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode))
            if os.geteuid() == 0:
                os.fchown(stream.fileno(), metadata.st_uid, metadata.st_gid)
        os.replace(temporary_name, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except Exception:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sudo_pam", type=Path)
    parser.add_argument("system_auth", type=Path)
    parser.add_argument("--check", action="store_true", help="validate and print the proposed sudo PAM file without writing")
    args = parser.parse_args()
    try:
        original = args.sudo_pam.read_text(encoding="utf-8")
        system_auth = args.system_auth.read_text(encoding="utf-8")
        replacement = render_sudo_pam(original, system_auth)
        if args.check:
            print(replacement, end="")
        elif replacement != original:
            _atomic_replace(args.sudo_pam, replacement)
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
