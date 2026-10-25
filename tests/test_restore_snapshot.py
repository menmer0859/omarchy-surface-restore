#!/usr/bin/env python3
"""Exercise real snapshot restoration against temporary filesystem roots."""

from __future__ import annotations

import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
RESTORER = REPO / "modules/face-auth/scripts/restore-snapshot.py"


class RestoreSnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="surface-restore-test-")
        self.base = Path(self.temp.name)
        self.snapshot = self.base / "snapshot"
        self.target = self.base / "target"
        self.snapshot.mkdir(mode=0o700)
        self.target.mkdir(mode=0o755)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_restore(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(RESTORER), "--snapshot", str(self.snapshot), "--target-root", str(self.target)],
            text=True,
            capture_output=True,
            check=False,
            env=os.environ | {"SURFACE_SETUP_TESTING": "1"},
        )

    def test_restores_files_without_applying_snapshot_root_permissions(self) -> None:
        backed_up = self.snapshot / "etc/pam.d/sudo"
        backed_up.parent.mkdir(parents=True)
        backed_up.write_text("auth include system-auth\n", encoding="utf-8")
        backed_up.chmod(0o640)
        (self.snapshot / ".backed_up_paths").write_text("/etc/pam.d/sudo\n", encoding="utf-8")

        result = self.run_restore()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o755)
        restored = self.target / "etc/pam.d/sudo"
        self.assertEqual(restored.read_text(encoding="utf-8"), "auth include system-auth\n")
        self.assertEqual(stat.S_IMODE(restored.stat().st_mode), 0o640)

    def test_reproduces_legacy_tar_root_metadata_bug_only_inside_fixture(self) -> None:
        source = self.snapshot
        source.chmod(0o700)
        (source / "fixture.txt").write_text("fixture only\n", encoding="utf-8")
        target = self.base / "legacy-target"
        target.mkdir(mode=0o755)
        archive = self.base / "legacy.tar"
        subprocess.run(["tar", "-C", str(source), "-cf", str(archive), "."], check=True)
        before = stat.S_IMODE(target.stat().st_mode)
        with archive.open("rb") as stream:
            subprocess.run(["tar", "-C", str(target), "-xpf", "-"], stdin=stream, check=True)
        self.assertEqual(before, 0o755)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o700)

    def test_does_not_change_metadata_of_existing_parent_directories(self) -> None:
        existing_parent = self.target / "etc/pam.d"
        existing_parent.mkdir(parents=True, mode=0o750)
        existing_parent.chmod(0o750)
        old_mode = stat.S_IMODE(existing_parent.stat().st_mode)
        backed_up = self.snapshot / "etc/pam.d/sudo"
        backed_up.parent.mkdir(parents=True)
        backed_up.write_text("old policy\n", encoding="utf-8")
        (self.snapshot / ".backed_up_paths").write_text("/etc/pam.d/sudo\n", encoding="utf-8")

        result = self.run_restore()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(stat.S_IMODE(existing_parent.stat().st_mode), old_mode)

    def test_removes_only_recorded_created_paths_and_prunes_empty_directories(self) -> None:
        created_dir = self.target / "usr/local/libexec/surface"
        created_dir.mkdir(parents=True)
        created_file = created_dir / "helper"
        created_file.write_text("project helper\n", encoding="utf-8")
        keep_file = self.target / "usr/local/libexec/keep"
        keep_file.write_text("unrelated\n", encoding="utf-8")
        (self.snapshot / ".created_paths").write_text(
            "/usr/local/libexec/surface/helper\n/usr/local/libexec/surface\n", encoding="utf-8"
        )

        result = self.run_restore()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(created_file.exists())
        self.assertFalse(created_dir.exists())
        self.assertEqual(keep_file.read_text(encoding="utf-8"), "unrelated\n")
        repeated = self.run_restore()
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertEqual(keep_file.read_text(encoding="utf-8"), "unrelated\n")

    def test_legacy_restore_never_deploys_uninstall_archives(self) -> None:
        (self.snapshot / "models").mkdir()
        (self.snapshot / "models/alice.dat").write_text("private model")
        (self.snapshot / "removed-plugins/surface.lock").mkdir(parents=True)
        (self.snapshot / "removed-plugins/surface.lock/manifest.json").write_text("{}")
        result = self.run_restore()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.target / "models").exists())
        self.assertFalse((self.target / "removed-plugins").exists())

    def test_missing_indexed_backup_stops_before_deleting_created_files(self) -> None:
        (self.snapshot / ".backed_up_paths").write_text("/etc/pam.d/sudo\n")
        (self.snapshot / ".created_paths").write_text("/helper\n")
        (self.target / "helper").write_text("needed by the current PAM stack")
        result = self.run_restore()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.target / "helper").exists())

    def test_restores_a_symlink_without_following_it(self) -> None:
        source = self.snapshot / "etc/howdy/current-camera"
        source.parent.mkdir(parents=True)
        source.symlink_to("/dev/v4l/by-path/ir-camera")
        (self.snapshot / ".backed_up_paths").write_text("/etc/howdy/current-camera\n", encoding="utf-8")

        result = self.run_restore()

        self.assertEqual(result.returncode, 0, result.stderr)
        restored = self.target / "etc/howdy/current-camera"
        self.assertTrue(restored.is_symlink())
        self.assertEqual(os.readlink(restored), "/dev/v4l/by-path/ir-camera")

    def test_removes_new_files_inside_a_restored_existing_directory(self) -> None:
        current = self.target / "etc/howdy"
        current.mkdir(parents=True)
        (current / "config.ini").write_text("new configuration\n", encoding="utf-8")
        (current / "new-extra.ini").write_text("installer addition\n", encoding="utf-8")
        saved = self.snapshot / "etc/howdy"
        saved.mkdir(parents=True)
        (saved / "config.ini").write_text("original configuration\n", encoding="utf-8")
        (self.snapshot / ".backed_up_paths").write_text("/etc/howdy\n", encoding="utf-8")
        (self.snapshot / ".created_paths").write_text("/etc/howdy/new-extra.ini\n", encoding="utf-8")

        result = self.run_restore()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((current / "config.ini").read_text(encoding="utf-8"), "original configuration\n")
        self.assertFalse((current / "new-extra.ini").exists())

    def test_rejects_a_created_path_that_escapes_the_target_root(self) -> None:
        (self.snapshot / ".created_paths").write_text("/../outside\n", encoding="utf-8")

        result = self.run_restore()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe path", result.stderr)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o755)

    def test_refuses_to_follow_a_symlink_parent_while_removing_created_paths(self) -> None:
        outside = self.base / "outside"
        outside.mkdir()
        protected = outside / "sudoers"
        protected.write_text("keep this file\n", encoding="utf-8")
        (self.target / "etc").symlink_to(outside, target_is_directory=True)
        (self.snapshot / ".created_paths").write_text("/etc/sudoers\n", encoding="utf-8")

        result = self.run_restore()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlink", result.stderr)
        self.assertEqual(protected.read_text(encoding="utf-8"), "keep this file\n")


if __name__ == "__main__":
    unittest.main()
