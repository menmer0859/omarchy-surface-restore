import hashlib
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PACKAGE = ROOT / "modules/face-auth/packaging/quickshell-polkit-restart"


class PolkitRestartPackageTests(unittest.TestCase):
    def recipe_fields(self):
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; printf "%s\\n" "$pkgname" "$pkgver-$pkgrel" "$_commit" "${source[@]}" "${sha256sums[@]}"',
             "recipe", str(PACKAGE / "PKGBUILD")],
            check=True, capture_output=True, text=True,
        )
        return result.stdout.splitlines()

    def test_local_package_replaces_current_quickshell_without_downgrading(self):
        fields = self.recipe_fields()
        self.assertEqual(fields[0], "quickshell")
        result = subprocess.run(["vercmp", fields[1], "0.3.2.r7.g2b4501a-1"],
                                check=True, capture_output=True, text=True)
        self.assertGreater(int(result.stdout), 0)
        self.assertEqual(fields[2], "2b4501a282689792b62e94f3fb30d8f512324fe6")

    def test_source_and_patch_integrity_can_be_verified_before_building(self):
        fields = self.recipe_fields()
        self.assertIn("/archive/2b4501a282689792b62e94f3fb30d8f512324fe6.tar.gz", fields[3])
        for name, digest in zip(fields[4:6], fields[7:9]):
            with self.subTest(patch=name):
                self.assertEqual(hashlib.sha256((PACKAGE / name).read_bytes()).hexdigest(), digest)


if __name__ == "__main__":
    unittest.main()
