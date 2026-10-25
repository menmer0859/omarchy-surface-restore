import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EXPORTER = REPO_ROOT / "modules/face-auth/scripts/export-setup-plugin.py"


class SetupPluginExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.output = Path(self.temp.name) / "export"
        self.output_second = Path(self.temp.name) / "export-second"
        self._make_source_tree()

    def _write(self, relative, content="source\n"):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def _make_source_tree(self):
        self._write("modules/face-auth/assets/face-setup/manifest.json", json.dumps({
            "schemaVersion": 1,
            "id": "surface.face-setup",
            "name": "Surface Face Setup",
            "version": "1.0.0",
            "kinds": ["bar-widget"],
            "entryPoints": {"barWidget": "Panel.qml"},
        }))
        self._write("modules/face-auth/assets/face-setup/Panel.qml")
        self._write("modules/face-auth/assets/face-setup/SetupModel.js")
        self._write("modules/face-auth/assets/face-setup/SetupStrings.qml")
        self._write("modules/face-auth/assets/face-setup/i18n/en.json", "{}\n")
        self._write("modules/face-auth/assets/face-setup/i18n/zh-CN.json", "{}\n")
        self._write("modules/face-auth/assets/face-ui/AuthStrings.qml")
        self._write("modules/face-auth/assets/face-ui/i18n/en.json", "{}\n")
        self._write("modules/face-auth/assets/face-ui/i18n/zh-CN.json", "{}\n")
        self._write("modules/face-auth/assets/omarchy-lock/Service.qml")
        self._write("modules/face-auth/assets/omarchy-lock/FaceUi/AuthStrings.qml")
        self._write("modules/face-auth/assets/omarchy-lock/FaceUi/i18n/en.json", "{}\n")
        self._write("modules/face-auth/assets/omarchy-polkit/PolkitAgent.qml")
        self._write("modules/face-auth/scripts/install-face.sh")
        self._write("modules/face-auth/scripts/install-howdy-base.sh")
        self._write("modules/face-auth/scripts/install-lock-face.sh")
        self._write("modules/face-auth/scripts/face-setup-status.py")
        self._write("modules/face-auth/scripts/run-face-setup.sh")
        self._write("modules/face-auth/packaging/quickshell-polkit-restart/PKGBUILD")
        self._write("modules/face-auth/install.sh")
        self._write("lib/common.sh")
        self._write("lib/restore.sh")

    def _export(self):
        return subprocess.run(
            ["python3", str(EXPORTER), "--source-root", str(self.root), "--output", str(self.output)],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_exports_root_manifest_and_runtime_files_without_symlinks(self):
        result = self._export()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / "manifest.json").is_file())
        manifest = json.loads((self.output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "surface.face-setup")
        for relative in (
            "Panel.qml",
            "SetupStrings.qml",
            "i18n/en.json",
            "i18n/zh-CN.json",
            "modules/face-auth/scripts/face-setup-status.py",
            "modules/face-auth/scripts/run-face-setup.sh",
            "modules/face-auth/scripts/install-howdy-base.sh",
            "modules/face-auth/scripts/install-lock-face.sh",
            "modules/face-auth/assets/omarchy-lock/Service.qml",
            "modules/face-auth/assets/omarchy-lock/FaceUi/AuthStrings.qml",
            "modules/face-auth/assets/omarchy-polkit/PolkitAgent.qml",
            "lib/common.sh",
            "lib/restore.sh",
        ):
            self.assertTrue((self.output / relative).is_file(), relative)
        self.assertFalse(any(path.is_symlink() for path in self.output.rglob("*")))

    def test_export_is_content_deterministic(self):
        first = self._export()
        self.assertEqual(first.returncode, 0, first.stderr)
        original = {p.relative_to(self.output): p.read_bytes() for p in self.output.rglob("*") if p.is_file()}
        self.output = self.output_second
        second = self._export()
        self.assertEqual(second.returncode, 0, second.stderr)
        current = {p.relative_to(self.output): p.read_bytes() for p in self.output.rglob("*") if p.is_file()}
        self.assertEqual(current, original)

    def test_broken_source_symlink_fails_clearly(self):
        path = self.root / "modules/face-auth/assets/omarchy-lock/FaceUi/AuthStrings.qml"
        path.unlink()
        path.symlink_to("missing.qml")
        result = self._export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("broken symlink", result.stderr.lower())

    def test_out_of_tree_source_symlink_fails_clearly(self):
        outside = Path(self.temp.name) / "outside.qml"
        outside.write_text("outside\n", encoding="utf-8")
        path = self.root / "modules/face-auth/assets/omarchy-lock/FaceUi/AuthStrings.qml"
        path.unlink()
        path.symlink_to(outside)
        result = self._export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outside repository", result.stderr.lower())

    def test_missing_required_asset_fails(self):
        (self.root / "modules/face-auth/assets/face-setup/i18n/zh-CN.json").unlink()
        result = self._export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing required file", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
