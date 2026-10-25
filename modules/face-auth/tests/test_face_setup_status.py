import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "modules/face-auth/scripts/face-setup-status.py"
SPEC = importlib.util.spec_from_file_location("face_setup_status", SCRIPT)
status_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(status_module)


class FaceSetupStatusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "root"
        self.home = self.root / "home/alice"
        self._touch("usr/share/omarchy/shell/services/PluginRegistry.qml")
        self._touch("usr/share/omarchy/shell/Commons/Translations.qml")
        self._touch("usr/bin/omarchy-plugin-validate", mode=0o755)
        self._touch("var/lib/pacman/local/omarchy-4.5.0rc1-1/desc", "%NAME%\nomarchy\n\n%VERSION%\n4.5.0rc1-1\n")
        self._touch("usr/bin/howdy", mode=0o755)
        self._touch("etc/howdy/config.ini", "[video]\ndevice_path = /dev/video2\n")
        self._touch("etc/howdy/models/alice.dat", "model\n")
        self._touch("etc/pam.d/omarchy-lock-password", "auth required pam_unix.so\n")
        self._touch("etc/pam.d/omarchy-lock-face", "auth sufficient pam_howdy.so\n")
        self._touch("etc/pam.d/sudo", "auth sufficient pam_exec.so /usr/local/libexec/omarchy-sudo-face-consent\n")
        self._touch("usr/local/libexec/omarchy-sudo-face-consent", mode=0o755)
        self._touch("etc/pam.d/polkit-1", "auth sufficient pam_surface_face_consent.so\n")
        self._touch("usr/local/lib/security/pam_surface_face_consent.so")
        self._touch("usr/local/libexec/omarchy-polkit-howdy", mode=0o755)
        self._touch("etc/systemd/system/polkit-agent-helper@.service.d/60-omarchy-surface-face.conf")
        self._touch("etc/systemd/system/quickshell.service.d/90-polkit-camera.conf")
        plugins = self.home / ".config/omarchy/plugins"
        shell_config = self.home / ".config/omarchy/shell.json"
        shell_config.parent.mkdir(parents=True, exist_ok=True)
        shell_config.write_text(json.dumps({"plugins": [{"id": "surface.lock"}, {"id": "alice.polkit"}]}), encoding="utf-8")
        (plugins / "surface.lock").mkdir(parents=True)
        (plugins / "surface.lock/manifest.json").write_text(json.dumps({
            "id": "surface.lock", "omarchy": {"clonedFrom": "omarchy.lock"}
        }), encoding="utf-8")
        (plugins / "alice.polkit").mkdir()
        (plugins / "alice.polkit/manifest.json").write_text(json.dumps({
            "id": "alice.polkit", "omarchy": {"clonedFrom": "omarchy.polkit", "surfaceFaceAuth": True}
        }), encoding="utf-8")
        self._touch("dev/video2", mode=0o600)
        camera_dir = self.root / "dev/v4l/by-path"
        camera_dir.mkdir(parents=True)
        (camera_dir / "pci-ir-video-index0").symlink_to("../../video2")

    def _touch(self, relative, content="", mode=0o644):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        path.chmod(mode)
        return path

    def _collect(self):
        return status_module.collect_status(self.root, self.home, "alice")

    def _tree_digest(self):
        digest = hashlib.sha256()
        for path in sorted(self.root.rglob("*")):
            if path.is_file() and not path.is_symlink():
                digest.update(str(path.relative_to(self.root)).encode())
                digest.update(path.read_bytes())
        return digest.digest()

    def test_reports_all_configured_authentication_flows(self):
        result = self._collect()
        self.assertTrue(result["platform"]["pluginApi"])
        self.assertEqual(result["platform"]["version"], "4.5.0rc1-1")
        self.assertTrue(result["platform"]["supportedBaseline"])
        self.assertTrue(result["camera"]["available"])
        self.assertTrue(result["howdy"]["ready"])
        self.assertTrue(result["lock"]["ready"])
        self.assertTrue(result["lock"]["passwordFallback"])
        self.assertTrue(result["sudo"]["enabled"])
        self.assertTrue(result["sudo"]["ready"])
        self.assertTrue(result["polkit"]["enabled"])
        self.assertTrue(result["polkit"]["ready"])
        self.assertEqual(result["polkit"]["returnToFace"], "unknown")

    def test_disabled_override_wins_over_a_plugin_entry(self):
        config = self.home / ".config/omarchy/shell.json"
        config.write_text(json.dumps({"plugins": [{"id": "surface.lock"}, {"id": "alice.polkit"}],
                                      "disabledPlugins": ["surface.lock", "alice.polkit"]}))
        result = self._collect()
        self.assertFalse(result["lock"]["pluginEnabled"])
        self.assertFalse(result["polkit"]["pluginEnabled"])

    def test_string_plugin_entries_do_not_match_omarchy_object_schema(self):
        (self.home / ".config/omarchy/shell.json").write_text(
            json.dumps({"plugins": ["surface.lock", "alice.polkit"]}))
        self.assertFalse(self._collect()["lock"]["pluginEnabled"])

    def test_another_accounts_polkit_plugin_does_not_make_this_account_ready(self):
        plugins = self.home / ".config/omarchy/plugins"
        (plugins / "alice.polkit/manifest.json").unlink()
        (plugins / "bob.polkit").mkdir()
        (plugins / "bob.polkit/manifest.json").write_text(json.dumps({
            "id": "bob.polkit", "omarchy": {"clonedFrom": "omarchy.polkit", "surfaceFaceAuth": True}}))
        self.assertFalse(self._collect()["polkit"]["ready"])

    def test_missing_camera_and_model_are_reported_without_mutation(self):
        (self.root / "dev/v4l/by-path/pci-ir-video-index0").unlink()
        (self.root / "etc/howdy/models/alice.dat").unlink()
        before = self._tree_digest()
        result = self._collect()
        after = self._tree_digest()
        self.assertFalse(result["camera"]["available"])
        self.assertFalse(result["howdy"]["ready"])
        self.assertFalse(result["lock"]["ready"])
        self.assertFalse(result["sudo"]["ready"])
        self.assertFalse(result["polkit"]["ready"])
        self.assertEqual(before, after)

    def test_reports_competing_lock_clone_even_with_a_different_plugin_id(self):
        plugin = self.home / ".config/omarchy/plugins/other.lock"
        plugin.mkdir()
        (plugin / "manifest.json").write_text(json.dumps({
            "id": "other.lock", "omarchy": {"clonedFrom": "omarchy.lock"}
        }), encoding="utf-8")
        result = self._collect()
        self.assertTrue(result["lock"]["conflict"])
        self.assertFalse(result["lock"]["ready"])

    def test_hidden_omarchy_backup_is_ignored_for_clone_conflicts(self):
        plugin = self.home / ".config/omarchy/plugins/.old-lock.bak.20261026"
        plugin.mkdir()
        (plugin / "manifest.json").write_text(json.dumps({
            "id": "old-lock", "omarchy": {"clonedFrom": "omarchy.lock"}
        }), encoding="utf-8")
        result = self._collect()
        self.assertFalse(result["lock"]["conflict"])

    def test_disabled_installed_plugins_are_not_reported_ready(self):
        (self.home / ".config/omarchy/shell.json").write_text('{"plugins": []}', encoding="utf-8")
        result = self._collect()
        self.assertTrue(result["lock"]["pluginInstalled"])
        self.assertFalse(result["lock"]["pluginEnabled"])
        self.assertFalse(result["lock"]["ready"])
        self.assertFalse(result["polkit"]["pluginEnabled"])
        self.assertFalse(result["polkit"]["ready"])

    def test_authentication_enabled_without_camera_access_is_not_ready(self):
        with patch.object(status_module.os, "access", return_value=False):
            result = self._collect()
        self.assertFalse(result["camera"]["accessible"])
        self.assertFalse(result["lock"]["ready"])
        self.assertFalse(result["sudo"]["ready"])
        self.assertFalse(result["polkit"]["ready"])

    def test_missing_password_fallback_keeps_lock_unready(self):
        (self.root / "etc/pam.d/omarchy-lock-password").unlink()
        result = self._collect()
        self.assertFalse(result["lock"]["passwordFallback"])
        self.assertFalse(result["lock"]["ready"])

    def test_detect_only_check_does_not_run_external_commands_or_write(self):
        before = self._tree_digest()
        result = self._collect()
        self.assertIn("checks", result)
        self.assertEqual(before, self._tree_digest())


if __name__ == "__main__":
    unittest.main()
