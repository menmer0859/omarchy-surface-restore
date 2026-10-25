import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "modules/face-auth/assets/face-setup"


class FaceSetupUiTests(unittest.TestCase):
    def test_manifest_exposes_a_single_installable_setup_bar_widget(self):
        manifest = json.loads((ASSETS / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "surface.face-setup")
        self.assertEqual(manifest["kinds"], ["bar-widget"])
        self.assertEqual(manifest["entryPoints"]["barWidget"], "Panel.qml")

    def test_english_and_chinese_have_the_same_complete_setup_copy(self):
        english = json.loads((ASSETS / "i18n/en.json").read_text(encoding="utf-8"))
        chinese = json.loads((ASSETS / "i18n/zh-CN.json").read_text(encoding="utf-8"))
        self.assertEqual(set(english), set(chinese))
        for key in ("setup.title", "setup.lock", "setup.sudo", "setup.polkit", "setup.check",
                    "setup.configure", "setup.passwordFallback", "setup.installNotice", "setup.afterTerminal",
                    "status.conflict"):
            self.assertIn(key, english)

    def test_panel_uses_read_only_status_and_explicit_independent_selection(self):
        panel = (ASSETS / "Panel.qml").read_text(encoding="utf-8")
        for marker in ("KeyboardPanel", "face-setup-status.py", "run-face-setup.sh", "CheckBox",
                       "lockSelected", "sudoSelected", "polkitSelected", "startSetup", "passwordFallback", "setupPending",
                       "status.lock && status.lock.ready", "status.sudo && status.sudo.ready",
                       "status.polkit && status.polkit.ready", "status.lock.conflict",
                       "status.passwordFallback",
                       "/.config/omarchy/plugins/surface.face-setup"):
            self.assertIn(marker, panel)
        self.assertNotIn("/dev/video", panel)
        self.assertNotIn("pam_howdy", panel)


if __name__ == "__main__":
    unittest.main()
