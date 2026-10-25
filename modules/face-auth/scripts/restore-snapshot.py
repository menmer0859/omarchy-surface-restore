#!/usr/bin/env python3
"""Restore recorded paths without applying snapshot-root metadata to the target."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import sys
import tempfile
from pathlib import Path, PurePosixPath


METADATA_FILES = {".created_paths", ".backed_up_paths", ".surface_module", ".surface_state.json"}


class RestoreError(Exception):
    pass


def read_paths(snapshot: Path, filename: str) -> list[PurePosixPath]:
    record = snapshot / filename
    if not record.exists():
        return []
    if record.is_symlink() or not record.is_file():
        raise RestoreError(f"invalid snapshot metadata: {filename}")
    paths: list[PurePosixPath] = []
    for raw in record.read_text(encoding="utf-8").splitlines():
        if not raw:
            continue
        path = PurePosixPath(raw)
        if not path.is_absolute() or ".." in path.parts or path == PurePosixPath("/"):
            raise RestoreError(f"unsafe path in {filename}: {raw!r}")
        if path not in paths:
            paths.append(path)
    return paths


def _relative_target(target_root: Path, absolute_path: PurePosixPath) -> Path:
    target = target_root
    for component in absolute_path.parts[1:]:
        target = target / component
    try:
        target.relative_to(target_root)
    except ValueError as error:
        raise RestoreError(f"unsafe path outside target root: {absolute_path}") from error
    return target


def _validate_safe_parent(path: Path, target_root: Path) -> None:
    relative = path.parent.relative_to(target_root)
    current = target_root
    for component in relative.parts:
        current = current / component
        if current.is_symlink():
            raise RestoreError(f"refusing to follow symlink in target path: {current}")
        if current.exists() and not current.is_dir():
            raise RestoreError(f"target parent is not a directory: {current}")


def _ensure_safe_parent(path: Path, target_root: Path) -> None:
    _validate_safe_parent(path, target_root)
    relative = path.parent.relative_to(target_root)
    current = target_root
    for component in relative.parts:
        current = current / component
        current.mkdir(mode=0o755, exist_ok=True)


def _copy_owner(source: Path, destination: Path, *, symlink: bool = False) -> None:
    if os.geteuid() != 0:
        return
    source_stat = source.lstat() if symlink else source.stat()
    try:
        os.chown(destination, source_stat.st_uid, source_stat.st_gid, follow_symlinks=not symlink)
    except (NotImplementedError, PermissionError, OSError) as error:
        raise RestoreError(f"could not restore ownership for {destination}: {error}") from error


def _copy_file(source: Path, destination: Path, target_root: Path) -> None:
    _ensure_safe_parent(destination, target_root)
    if source.is_symlink():
        link_target = os.readlink(source)
        if destination.exists() or destination.is_symlink():
            if destination.is_dir() and not destination.is_symlink():
                raise RestoreError(f"cannot replace directory with symlink: {destination}")
            destination.unlink()
        destination.symlink_to(link_target)
        _copy_owner(source, destination, symlink=True)
        return

    fd, temporary_name = tempfile.mkstemp(prefix=f".{destination.name}.restore-", dir=destination.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        shutil.copy2(source, temporary, follow_symlinks=False)
        _copy_owner(source, temporary)
        shutil.copystat(source, temporary, follow_symlinks=False)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def _copy_tree(source: Path, destination: Path, target_root: Path, *, restore_root_metadata: bool) -> None:
    if source.is_symlink():
        _copy_file(source, destination, target_root)
        return
    if source.is_dir():
        _ensure_safe_parent(destination, target_root)
        if destination.is_symlink():
            destination.unlink()
        elif destination.exists() and not destination.is_dir():
            destination.unlink()
        created = not destination.exists()
        destination.mkdir(mode=stat.S_IMODE(source.stat().st_mode), exist_ok=True)
        for child in sorted(source.iterdir(), key=lambda item: item.name):
            _copy_tree(child, destination / child.name, target_root, restore_root_metadata=False)
        if restore_root_metadata:
            _copy_owner(source, destination)
            shutil.copystat(source, destination, follow_symlinks=False)
        elif created:
            _copy_owner(source, destination)
            shutil.copystat(source, destination, follow_symlinks=False)
        return
    if not source.is_file():
        raise RestoreError(f"unsupported snapshot entry: {source}")
    _copy_file(source, destination, target_root)


def _fallback_backup_paths(snapshot: Path) -> list[PurePosixPath]:
    """Legacy snapshots have no exact-path index; restore leaves only."""
    paths: list[PurePosixPath] = []
    for entry in sorted(snapshot.iterdir(), key=lambda item: item.name):
        if entry.name in METADATA_FILES:
            continue
        for candidate in sorted(entry.rglob("*"), key=lambda item: str(item)):
            if candidate.is_symlink() or candidate.is_file():
                relative = candidate.relative_to(snapshot)
                paths.append(PurePosixPath("/") / PurePosixPath(*relative.parts))
    return paths


def _remove_created(target: Path) -> None:
    if target.is_symlink() or target.is_file():
        target.unlink(missing_ok=True)
        return
    if target.is_dir():
        try:
            target.rmdir()
        except OSError:
            print(f"Kept non-empty directory containing unrecorded files: {target}", file=sys.stderr)


def restore(snapshot_path: Path, target_root: Path) -> None:
    if snapshot_path.is_symlink() or not snapshot_path.is_dir():
        raise RestoreError(f"snapshot must be a real directory: {snapshot_path}")
    snapshot = snapshot_path.resolve(strict=True)
    if target_root.is_symlink() or not target_root.is_dir():
        raise RestoreError(f"target root must be a real directory: {target_root}")
    target = target_root.resolve(strict=True)

    backed_up_record = snapshot / ".backed_up_paths"
    backed_up = read_paths(snapshot, ".backed_up_paths")
    if not backed_up_record.exists():
        backed_up = _fallback_backup_paths(snapshot)
    created = read_paths(snapshot, ".created_paths")

    restore_plan: list[tuple[Path, Path]] = []
    for absolute in backed_up:
        source = snapshot.joinpath(*absolute.parts[1:])
        destination = _relative_target(target, absolute)
        if source.is_symlink() or source.exists():
            restore_plan.append((source, destination))

    # Validate every destination before the first write so a bad later record
    # cannot leave a partially restored tree.
    for _, destination in restore_plan:
        try:
            destination.relative_to(target)
        except ValueError as error:
            raise RestoreError(f"unsafe path outside target root: {destination}") from error
        _validate_safe_parent(destination, target)
    for absolute in created:
        _validate_safe_parent(_relative_target(target, absolute), target)

    for source, destination in restore_plan:
        _copy_tree(source, destination, target, restore_root_metadata=True)

    for absolute in sorted(created, key=lambda value: (len(value.parts), str(value)), reverse=True):
        _remove_created(_relative_target(target, absolute))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--target-root", type=Path, default=Path("/"), help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.target_root != Path("/") and not (
        os.environ.get("SURFACE_SETUP_TESTING") == "1"
        and args.target_root.is_absolute()
        and args.target_root.is_relative_to(Path("/tmp"))
    ):
        parser.error("custom restore roots are allowed only in isolated tests")
    try:
        restore(args.snapshot, args.target_root)
    except (OSError, RestoreError, ValueError) as error:
        print(f"restore-snapshot: {error}", file=sys.stderr)
        return 1
    print(f"Restored recorded paths from {args.snapshot}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
