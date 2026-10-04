#!/usr/bin/env python3
"""Add consent-gated Howdy authentication to one Polkit PAM service."""

from __future__ import annotations

import argparse
import os
import re
import stat
import tempfile
from pathlib import Path


BEGIN = "# BEGIN omarchy-surface-restore polkit face authentication"
END = "# END omarchy-surface-restore polkit face authentication"
MODULE = "/usr/local/lib/security/pam_surface_face_consent.so"
HOWDY_HELPER = "/usr/local/libexec/omarchy-polkit-howdy"


def _faillock_options(system_auth: str, marker: str) -> str:
    found = []
    for line in system_auth.splitlines():
        fields = line.split()
        if len(fields) < 4 or fields[0] != "auth" or fields[2] != "pam_faillock.so":
            continue
        if marker in fields[3:]:
            found.append(fields)
    if len(found) != 1:
        raise ValueError(f"expected exactly one auth pam_faillock.so {marker} rule in system-auth")
    options = [arg for arg in found[0][3:] if arg != marker]
    return (" " + " ".join(options)) if options else ""


def render_polkit_pam(polkit_config: str, system_auth: str) -> str:
    preauth_options = _faillock_options(system_auth, "preauth")
    authsucc_options = _faillock_options(system_auth, "authsucc")

    lines = polkit_config.splitlines(keepends=True)
    managed = False
    clean: list[str] = []
    for line in lines:
        stripped = line.rstrip("\r\n")
        if stripped == BEGIN:
            if managed:
                raise ValueError("duplicate Polkit face authentication markers")
            managed = True
            continue
        if stripped == END:
            if not managed:
                raise ValueError("unmatched Polkit face authentication end marker")
            managed = False
            continue
        if not managed:
            clean.append(line)
    if managed:
        raise ValueError("unclosed Polkit face authentication marker")

    base = "".join(clean)
    if re.search(r"^\s*auth\s+.*\bpam_(?:howdy|surface_face_consent)\.so\b", base, re.MULTILINE):
        raise ValueError("Polkit PAM already has an unmanaged face authentication rule")

    include_matches = [
        re.match(r"^(\s*)auth(\s+)include(\s+)system-auth(\s*(?:#.*)?)?(\r?\n)?$", line)
        for line in clean
    ]
    positions = [index for index, match in enumerate(include_matches) if match]
    if len(positions) != 1:
        raise ValueError("expected exactly one auth include system-auth rule in Polkit PAM")

    index = positions[0]
    for line in clean[index + 1 :]:
        fields = line.split("#", 1)[0].split()
        if fields and fields[0] == "auth":
            raise ValueError("auth rules after the system-auth include cannot be skipped on face success")

    match = include_matches[index]
    assert match is not None
    newline = match.group(5) or "\n"
    indent = match.group(1)
    rules = (
        f"{BEGIN}{newline}"
        f"{indent}auth requisite pam_faillock.so preauth{preauth_options}{newline}"
        f"{indent}auth [success=ok default=2] {MODULE}{newline}"
        f"{indent}auth [success=ok default=1] pam_exec.so quiet seteuid {HOWDY_HELPER}{newline}"
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
    parser.add_argument("polkit_pam", type=Path)
    parser.add_argument("system_auth", type=Path)
    parser.add_argument("--check", action="store_true", help="validate and print the proposed Polkit PAM file without writing")
    args = parser.parse_args()
    try:
        original = args.polkit_pam.read_text(encoding="utf-8")
        system_auth = args.system_auth.read_text(encoding="utf-8")
        replacement = render_polkit_pam(original, system_auth)
        if args.check:
            print(replacement, end="")
        elif replacement != original:
            _atomic_replace(args.polkit_pam, replacement)
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
