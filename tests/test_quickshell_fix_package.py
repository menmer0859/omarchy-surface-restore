import hashlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "packaging/quickshell-xdg-session"


class QuickshellFixPackageTests(unittest.TestCase):
    def test_package_applies_session_id_patch_to_pinned_arch_source(self):
        pkgbuild = (PACKAGE / "PKGBUILD").read_text(encoding="utf-8")
        patch = (PACKAGE / "quickshell-session-xdg-id.patch").read_text(encoding="utf-8")
        self.assertIn("pkgver=0.3.1", pkgbuild)
        self.assertIn("pkgrel=2", pkgbuild)
        self.assertIn("d60592622f1aa1cbb853d4814f605dfde827bc692befbfecffaccf4c90e352d8", pkgbuild)
        self.assertRegex(pkgbuild, r"prepare\(\)[\s\S]*patch -Np1")
        self.assertIn('qEnvironmentVariable("XDG_SESSION_ID")', patch)
        self.assertIn("polkit_unix_session_new(sessionIdUtf8.constData())", patch)
        patch_hash = hashlib.sha256((PACKAGE / "quickshell-session-xdg-id.patch").read_bytes()).hexdigest()
        self.assertIn(patch_hash, pkgbuild)

    def test_runtime_dependencies_are_pacman_package_names_not_sonames(self):
        pkgbuild = (PACKAGE / "PKGBUILD").read_text(encoding="utf-8")
        dependency_block = re.search(r"depends=\((.*?)\)\nmakedepends=", pkgbuild, re.S)
        self.assertIsNotNone(dependency_block)
        dependencies = []
        for line in dependency_block.group(1).splitlines():
            dependencies.extend(line.split("#", 1)[0].split())
        unresolved_sonames = {
            "libm.so",
            "libdrm.so",
            "libxcb.so",
            "libgbm.so",
            "libQt6Core.so",
            "libQt6DBus.so",
            "libQt6Gui.so",
            "libQt6Network.so",
            "libQt6Widgets.so",
            "libQt6Qml.so",
            "libQt6Quick.so",
            "libQt6WaylandClient.so",
        }
        self.assertFalse(unresolved_sonames.intersection(dependencies))
        for package in ("glibc", "libdrm", "libxcb", "mesa", "qt6-base", "qt6-declarative", "qt6-wayland"):
            self.assertIn(package, dependencies)


if __name__ == "__main__":
    unittest.main()
