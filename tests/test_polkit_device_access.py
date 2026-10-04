import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RENDERER = ROOT / "scripts/render-polkit-device-access.py"


class PolkitDeviceAccessTests(unittest.TestCase):
    def test_renders_only_the_selected_video_device_allow_rule(self):
        result = subprocess.run(
            [sys.executable, str(RENDERER), "/dev/video2"],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            result.stdout,
            "[Service]\nPrivateDevices=no\nDeviceAllow=/dev/video2 rw\n",
        )

    def test_rejects_non_video_paths(self):
        for device in ("/dev/null", "/dev/video2/../sda", "video2", "/dev/video999;id"):
            with self.subTest(device=device):
                result = subprocess.run(
                    [sys.executable, str(RENDERER), device],
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
