#!/usr/bin/env python3
"""Read-only readiness report for the Omarchy Surface face setup panel."""

from __future__ import annotations

import argparse
import configparser
import json
import os
from pathlib import Path
import re
import stat
import sys


def rooted(root: Path, absolute: str) -> Path:
    return root / absolute.lstrip("/")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def is_file(path: Path) -> bool:
    try:
        return path.is_file()
    except OSError:
        return False


def executable(path: Path) -> bool:
    try:
        return path.is_file() and bool(path.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH))
    except OSError:
        return False


def package_version(root: Path, package_name: str) -> str:
    database = rooted(root, "/var/lib/pacman/local")
    try:
        package_dirs = sorted(database.iterdir(), key=lambda item: item.name)
    except OSError:
        return ""
    for package_dir in package_dirs:
        desc = read_text(package_dir / "desc")
        match = re.search(r"(?m)^%NAME%\n([^\n]+)\n\n%VERSION%\n([^\n]+)", desc)
        if match and match.group(1) == package_name:
            return match.group(2)
    return ""


def camera_status(root: Path) -> dict:
    directory = rooted(root, "/dev/v4l/by-path")
    nodes = []
    try:
        candidates = sorted(directory.iterdir(), key=lambda item: item.name)
    except OSError:
        candidates = []
    for candidate in candidates:
        try:
            resolved = candidate.resolve(strict=True)
            expected_parent = root / "dev"
            if resolved.parent != expected_parent or not re.fullmatch(r"video\d+", resolved.name):
                continue
            if not resolved.exists():
                continue
            nodes.append({
                "path": str(candidate),
                "accessible": os.access(candidate, os.R_OK | os.W_OK),
            })
        except (OSError, RuntimeError):
            continue
    config = configparser.ConfigParser()
    config_path = rooted(root, "/etc/howdy/config.ini")
    try:
        config.read(config_path, encoding="utf-8")
        selected = config.get("video", "device_path", fallback="")
    except (OSError, configparser.Error):
        selected = ""
    return {
        "available": bool(nodes),
        "accessible": any(node["accessible"] for node in nodes),
        "nodeCount": len(nodes),
        "nodes": nodes,
        "selectedPath": selected,
    }


def _has_lock_clone_conflict(plugins_dir: Path) -> tuple[bool, str]:
    try:
        manifests = sorted(plugins_dir.glob("*/manifest.json"), key=lambda item: str(item))
    except OSError:
        manifests = []
    for manifest_path in manifests:
        if manifest_path.parent.name.startswith("."):
            continue
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(manifest, dict):
            continue
        metadata = manifest.get("omarchy") or {}
        if isinstance(metadata, dict) and metadata.get("clonedFrom") == "omarchy.lock" and manifest.get("id") != "surface.lock":
            return True, str(manifest_path.parent)
    return False, ""


def _user_plugin_enabled(home: Path, plugin_id: str) -> bool:
    config_path = home / ".config/omarchy/shell.json"
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    if not isinstance(config, dict) or plugin_id in config.get("disabledPlugins", []):
        return False
    entries = config.get("plugins", [])
    return isinstance(entries, list) and any(
        isinstance(entry, dict) and entry.get("id") == plugin_id for entry in entries)


def collect_status(root: Path | str = Path("/"), home: Path | str | None = None, username: str | None = None) -> dict:
    root = Path(root).resolve()
    username = username or os.environ.get("USER") or os.environ.get("LOGNAME") or ""
    if home is None:
        default_home = Path.home()
        home = rooted(root, str(default_home)) if root != Path("/") else default_home
    home = Path(home)

    validator = executable(rooted(root, "/usr/bin/omarchy-plugin-validate")) or executable(
        rooted(root, "/usr/local/bin/omarchy-plugin-validate")
    )
    registry = is_file(rooted(root, "/usr/share/omarchy/shell/services/PluginRegistry.qml"))
    translations = is_file(rooted(root, "/usr/share/omarchy/shell/Commons/Translations.qml"))
    version = package_version(root, "omarchy")
    plugin_api = validator and registry and translations

    camera = camera_status(root)
    howdy_binary = any(executable(rooted(root, candidate)) for candidate in ("/usr/bin/howdy", "/usr/local/bin/howdy"))
    howdy_config = is_file(rooted(root, "/etc/howdy/config.ini"))
    model = is_file(rooted(root, f"/etc/howdy/models/{username}.dat")) if username else False
    howdy = {"installed": howdy_binary, "configured": howdy_config, "modelEnrolled": model,
             "ready": howdy_binary and howdy_config and model}

    pam = rooted(root, "/etc/pam.d")
    password_fallback = is_file(pam / "omarchy-lock-password")
    face_pam = is_file(pam / "omarchy-lock-face") and "pam_howdy.so" in read_text(pam / "omarchy-lock-face")
    plugins_dir = home / ".config/omarchy/plugins"
    lock_conflict, conflict_path = _has_lock_clone_conflict(plugins_dir)
    lock_clone = is_file(plugins_dir / "surface.lock/manifest.json")
    lock_enabled = _user_plugin_enabled(home, "surface.lock")
    lock_ready = (password_fallback and face_pam and howdy["ready"] and camera["available"]
                  and camera["accessible"] and lock_clone and lock_enabled and not lock_conflict)
    lock = {
        "passwordFallback": password_fallback,
        "facePam": face_pam,
        "pluginInstalled": lock_clone,
        "pluginEnabled": lock_enabled,
        "conflict": lock_conflict,
        "conflictPlugin": conflict_path,
        "ready": lock_ready,
    }

    sudo_pam = read_text(pam / "sudo")
    sudo_helper = rooted(root, "/usr/local/libexec/omarchy-sudo-face-consent")
    sudo_enabled = is_file(sudo_helper) and "/usr/local/libexec/omarchy-sudo-face-consent" in sudo_pam
    camera_ready = camera["available"] and camera["accessible"]
    sudo_ready = sudo_enabled and howdy["ready"] and camera_ready
    sudo = {"enabled": sudo_enabled, "ready": sudo_ready}

    polkit_pam = read_text(pam / "polkit-1")
    polkit_module = rooted(root, "/usr/local/lib/security/pam_surface_face_consent.so")
    polkit_helper = rooted(root, "/usr/local/libexec/omarchy-polkit-howdy")
    polkit_dropin = rooted(root, "/etc/systemd/system/polkit-agent-helper@.service.d/60-omarchy-surface-face.conf")
    polkit_plugin_id = f"{username}.polkit" if username else ""
    try:
        manifest = json.loads(read_text(plugins_dir / polkit_plugin_id / "manifest.json"))
        metadata = manifest.get("omarchy") or {}
        polkit_plugin = (manifest.get("id") == polkit_plugin_id
                         and metadata.get("clonedFrom") == "omarchy.polkit"
                         and metadata.get("surfaceFaceAuth") is True)
    except (json.JSONDecodeError, AttributeError):
        polkit_plugin = False
    polkit_plugin_active = polkit_plugin and _user_plugin_enabled(home, polkit_plugin_id)
    polkit_enabled = ("pam_surface_face_consent.so" in polkit_pam and is_file(polkit_module)
                      and executable(polkit_helper) and is_file(polkit_dropin) and polkit_plugin_active)
    polkit_ready = polkit_enabled and howdy["ready"] and camera_ready
    polkit = {"enabled": polkit_enabled, "pluginInstalled": polkit_plugin,
              "pluginEnabled": polkit_plugin_active, "ready": polkit_ready, "returnToFace": "unknown"}

    return {
        "schemaVersion": 1,
        "platform": {
            "omarchy": bool(registry),
            "version": version,
            "pluginApi": bool(plugin_api),
            "supportedBaseline": version.startswith("4.5.0rc1"),
        },
        "camera": camera,
        "howdy": howdy,
        "lock": lock,
        "sudo": sudo,
        "polkit": polkit,
        "checks": {
            "camera": camera["available"] and camera["accessible"],
            "howdy": howdy["ready"],
            "lock": lock["ready"],
            "sudo": sudo_ready,
            "polkit": polkit_ready,
            "polkitReturnToFace": "unknown",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON (default)")
    parser.add_argument("--root", type=Path, default=Path("/"), help="filesystem root for tests")
    parser.add_argument("--home", type=Path, help="user home directory override")
    parser.add_argument("--user", help="enrolled account name")
    args = parser.parse_args()
    try:
        result = collect_status(args.root, args.home, args.user)
    except Exception as error:  # status reporting should return a stable error object
        print(json.dumps({"schemaVersion": 1, "error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
