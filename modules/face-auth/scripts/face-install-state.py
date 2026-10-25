#!/usr/bin/env python3
"""Maintain the protected, repeat-safe face-auth installation ledger."""

from __future__ import annotations

import argparse
import json
import hashlib
import os
import re
import stat
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

INTEGRATIONS = {"lock", "sudo", "polkit"}
STATUSES = {"installing", "installed", "uninstalling", "uninstalled"}


def _read(path: Path) -> dict | None:
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError(f"Refusing a symlink transaction record or parent: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"Untrusted or unreadable face-auth transaction record: {path}") from exc
    if not isinstance(value, dict) or value.get("schema_version") != 1:
        raise ValueError(f"Unsupported face-auth transaction record: {path}")
    if value.get("status") not in STATUSES:
        raise ValueError(f"Invalid status in face-auth transaction record: {path}")
    transaction_id = value.get("id", "")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", transaction_id) or ".." in transaction_id:
        raise ValueError(f"Invalid transaction ID in face-auth transaction record: {path}")
    return value


def _write(path: Path, state: dict) -> None:
    if path.is_symlink():
        raise ValueError(f"Refusing a symlink transaction record: {path}")
    if not path.parent.exists():
        path.parent.mkdir(mode=0o700, parents=True)
        os.chmod(path.parent, 0o700)
    elif path.parent.is_symlink() or not path.parent.is_dir():
        raise ValueError(f"Transaction record parent is not a real directory: {path.parent}")
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(state, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def begin(path: Path, user: str, packages_present: list[str], backup_id: str, integrations: list[str]) -> dict:
    if (not user or not re.fullmatch(r"[A-Za-z0-9._-]+", user) or not backup_id
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", backup_id) or ".." in backup_id
            or not integrations or set(integrations) - INTEGRATIONS):
        raise ValueError("A user, backup ID, and at least one valid integration are required")
    current = _read(path)
    if current and current["status"] != "uninstalled":
        if current.get("user") != user:
            raise ValueError("An active face-auth transaction belongs to a different user")
        current["integrations"] = sorted(set(current.get("integrations", [])) | set(integrations))
        current["updated_at"] = datetime.now(timezone.utc).isoformat()
        _write(path, current)
        return current
    current = {
        "schema_version": 1,
        "id": backup_id,
        "user": user,
        "status": "installing",
        "integrations": sorted(set(integrations)),
        "packages_present_before": sorted(set(packages_present)),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    _write(path, current)
    return current


def set_status(path: Path, status: str) -> dict:
    if status not in STATUSES:
        raise ValueError(f"Invalid status: {status}")
    current = _read(path)
    if current is None:
        raise ValueError("No face-auth transaction record exists")
    current["status"] = status
    current["updated_at"] = datetime.now(timezone.utc).isoformat()
    _write(path, current)
    return current


def _path_digest(path: Path) -> str:
    if not path.exists() and not path.is_symlink():
        return "missing"
    digest = hashlib.sha256()

    def add(candidate: Path, relative: str) -> None:
        metadata = candidate.lstat()
        mode = stat.S_IFMT(metadata.st_mode) | stat.S_IMODE(metadata.st_mode)
        digest.update(f"{relative}\0{mode:o}\0{metadata.st_uid}:{metadata.st_gid}\0".encode())
        if stat.S_ISLNK(metadata.st_mode):
            digest.update(b"symlink\0" + os.readlink(candidate).encode())
        elif stat.S_ISREG(metadata.st_mode):
            digest.update(b"file\0")
            with candidate.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
        elif stat.S_ISDIR(metadata.st_mode):
            digest.update(b"directory\0")
            for child in sorted(candidate.iterdir(), key=lambda item: item.name):
                add(child, f"{relative}/{child.name}")
        else:
            digest.update(b"special\0")

    add(path, ".")
    return digest.hexdigest()


def capture(path: Path, backup_root: Path, target_root: Path) -> dict:
    state = _read(path)
    if state is None:
        raise ValueError("No face-auth transaction record exists")
    snapshot = backup_root / state["id"]
    if snapshot.is_symlink() or not snapshot.is_dir():
        raise ValueError(f"Transaction snapshot is missing or unsafe: {snapshot}")
    paths: set[str] = set()
    for filename in (".created_paths", ".backed_up_paths"):
        record = snapshot / filename
        if not record.exists():
            continue
        if record.is_symlink() or not record.is_file():
            raise ValueError(f"Invalid snapshot metadata: {filename}")
        for raw in record.read_text(encoding="utf-8").splitlines():
            value = PurePosixPath(raw)
            if not value.is_absolute() or value == PurePosixPath("/") or ".." in value.parts:
                raise ValueError(f"Unsafe path in {filename}: {raw!r}")
            paths.add(str(value))
    digests = {}
    for absolute in sorted(paths):
        relative = Path(*PurePosixPath(absolute).parts[1:])
        target = target_root / relative
        digests[absolute] = _path_digest(target)
    state["installed_hashes"] = digests
    state["updated_at"] = datetime.now(timezone.utc).isoformat()
    _write(path, state)
    return state


def verify(path: Path, backup_root: Path, target_root: Path) -> list[str]:
    state = _read(path)
    if state is None:
        raise ValueError("No face-auth transaction record exists")
    snapshot = backup_root / state["id"]
    if snapshot.is_symlink() or not snapshot.is_dir():
        raise ValueError(f"Transaction snapshot is missing or unsafe: {snapshot}")
    tracked: set[str] = set()
    for filename in (".created_paths", ".backed_up_paths"):
        record = snapshot / filename
        if not record.exists():
            continue
        if record.is_symlink() or not record.is_file():
            raise ValueError(f"Invalid snapshot metadata: {filename}")
        for raw in record.read_text(encoding="utf-8").splitlines():
            value = PurePosixPath(raw)
            if not value.is_absolute() or value == PurePosixPath("/") or ".." in value.parts:
                raise ValueError(f"Unsafe path in {filename}: {raw!r}")
            tracked.add(str(value))
    expected = state.get("installed_hashes")
    if not isinstance(expected, dict):
        raise ValueError("This install was interrupted before its final state was recorded; automatic uninstall cannot verify which changes are still owned.")
    unverified = sorted(tracked - set(expected))
    if unverified:
        raise ValueError("The install record is incomplete for these paths: " + ", ".join(unverified))
    changed = []
    for absolute in sorted(tracked):
        relative = Path(*PurePosixPath(absolute).parts[1:])
        current = _path_digest(target_root / relative)
        if current != expected[absolute]:
            changed.append(absolute)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_state = Path("/var/lib/omarchy-surface-restore/face-auth.json")
    parser.add_argument("--state-file", type=Path, default=default_state)
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser("begin")
    start.add_argument("--user", required=True)
    start.add_argument("--backup-id", required=True)
    start.add_argument("--package-present", action="append", default=[])
    start.add_argument("--integration", action="append", choices=sorted(INTEGRATIONS), required=True)
    status = commands.add_parser("status")
    status.add_argument("value", choices=sorted(STATUSES))
    snapshot = commands.add_parser("capture")
    snapshot.add_argument("--backup-root", type=Path, default=Path("/var/backups/omarchy-surface-restore"))
    snapshot.add_argument("--target-root", type=Path, default=Path("/"))
    verify_parser = commands.add_parser("verify")
    verify_parser.add_argument("--backup-root", type=Path, default=Path("/var/backups/omarchy-surface-restore"))
    verify_parser.add_argument("--target-root", type=Path, default=Path("/"))
    commands.add_parser("show")
    args = parser.parse_args()
    testing = os.environ.get("SURFACE_SETUP_TESTING") == "1"
    if args.state_file != default_state and not (testing and args.state_file.is_absolute()
                                                  and args.state_file.is_relative_to(Path("/tmp"))):
        parser.error("custom transaction paths are allowed only in isolated tests")
    if args.command in {"capture", "verify"} and testing:
        if not args.backup_root.is_absolute() or not args.backup_root.is_relative_to(Path("/tmp")):
            parser.error("isolated test backup roots must be inside /tmp")
        if not args.target_root.is_absolute() or not args.target_root.is_relative_to(Path("/tmp")):
            parser.error("isolated test target roots must be inside /tmp")
    elif args.command in {"capture", "verify"} and args.target_root != Path("/"):
        parser.error("custom capture/verify roots are allowed only in isolated tests")
    try:
        if args.command == "begin":
            state = begin(args.state_file, args.user, args.package_present, args.backup_id, args.integration)
        elif args.command == "status":
            state = set_status(args.state_file, args.value)
        elif args.command == "capture":
            state = capture(args.state_file, args.backup_root, args.target_root)
        elif args.command == "verify":
            conflicts = verify(args.state_file, args.backup_root, args.target_root)
            if conflicts:
                for conflict in conflicts:
                    print(f"Changed since face-auth install: {conflict}")
                return 3
            print("All tracked paths match the last completed face-auth install.")
            return 0
        else:
            state = _read(args.state_file)
            if state is None:
                print("No tracked face-auth installation exists.")
                return 1
        print(json.dumps(state, sort_keys=True))
    except ValueError as exc:
        parser.exit(1, f"Error: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
