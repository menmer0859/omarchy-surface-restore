#!/usr/bin/env python3
"""Build a self-contained, regular-file Omarchy face setup plugin checkout."""

from __future__ import annotations

import argparse
import shutil
import stat
import sys
from pathlib import Path


EXPORT_PATHS = (
    "modules/face-auth/assets/face-setup",
    "modules/face-auth/assets/face-ui",
    "modules/face-auth/assets/omarchy-lock",
    "modules/face-auth/assets/omarchy-polkit",
    "modules/face-auth/packaging/quickshell-polkit-restart",
    "modules/face-auth/scripts",
    "modules/face-auth/install.sh",
    "uninstall.sh",
    "lib/common.sh",
    "lib/restore.sh",
)
REQUIRED_FILES = (
    "modules/face-auth/assets/face-setup/manifest.json",
    "modules/face-auth/assets/face-setup/Panel.qml",
    "modules/face-auth/assets/face-setup/SetupModel.js",
    "modules/face-auth/assets/face-setup/SetupStrings.qml",
    "modules/face-auth/assets/face-setup/i18n/en.json",
    "modules/face-auth/assets/face-setup/i18n/zh-CN.json",
    "modules/face-auth/scripts/install-face.sh",
    "modules/face-auth/scripts/install-howdy-base.sh",
    "modules/face-auth/scripts/install-lock-face.sh",
    "modules/face-auth/scripts/face-setup-status.py",
    "modules/face-auth/scripts/run-face-setup.sh",
    "modules/face-auth/scripts/face-install-state.py",
    "modules/face-auth/scripts/restore-snapshot.py",
    "modules/face-auth/scripts/uninstall-face-auth.sh",
    "modules/face-auth/install.sh",
    "uninstall.sh",
    "lib/common.sh",
    "lib/restore.sh",
)


class ExportError(Exception):
    pass


def _inside(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _copy_node(source: Path, destination: Path, root: Path) -> None:
    if source.is_symlink():
        try:
            resolved = source.resolve(strict=True)
        except (FileNotFoundError, RuntimeError) as error:
            raise ExportError(f"broken symlink: {source}") from error
        if not _inside(resolved, root):
            raise ExportError(f"symlink target is outside repository: {source} -> {resolved}")
        _copy_node(resolved, destination, root)
        return

    if not _inside(source, root):
        raise ExportError(f"source path is outside repository: {source}")
    if source.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
        for child in sorted(source.iterdir(), key=lambda item: item.name):
            if child.name in {"__pycache__", ".pytest_cache"} or child.suffix == ".pyc":
                continue
            _copy_node(child, destination / child.name, root)
        return
    if not source.is_file():
        raise ExportError(f"unsupported source file: {source}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    destination.chmod(stat.S_IMODE(source.stat().st_mode))


def export(source_root: Path, output: Path) -> None:
    root = source_root.resolve(strict=True)
    target = output.absolute()
    if _inside(target.resolve(), root):
        raise ExportError("output directory must be outside the source repository")
    if target.exists() and any(target.iterdir()):
        raise ExportError(f"output directory must be empty: {target}")
    target.mkdir(parents=True, exist_ok=True)

    for relative in REQUIRED_FILES:
        source = root / relative
        if not source.exists() and not source.is_symlink():
            raise ExportError(f"missing required file: {relative}")

    for relative in EXPORT_PATHS:
        source = root / relative
        if not source.exists() and not source.is_symlink():
            raise ExportError(f"missing required path: {relative}")
        destination = target / relative
        _copy_node(source, destination, root)

    setup_root = target / "modules/face-auth/assets/face-setup"
    for relative in ("manifest.json", "Panel.qml", "SetupModel.js", "SetupStrings.qml"):
        source = setup_root / relative
        if not source.is_file():
            raise ExportError(f"missing required file: modules/face-auth/assets/face-setup/{relative}")
        shutil.copyfile(source, target / relative)
    _copy_node(setup_root / "i18n", target / "i18n", target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, help="repository source root (defaults to this checkout)")
    parser.add_argument("--output", type=Path, required=True, help="new or empty directory for the plugin checkout")
    args = parser.parse_args()
    source_root = args.source_root or Path(__file__).resolve().parents[3]
    try:
        export(source_root, args.output)
    except (ExportError, OSError) as error:
        print(f"export-setup-plugin: {error}", file=sys.stderr)
        return 1
    print(f"Exported Omarchy plugin surface.face-setup to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
