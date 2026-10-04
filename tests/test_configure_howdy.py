import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "configure-howdy.py"
SPEC = importlib.util.spec_from_file_location("configure_howdy", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConfigureHowdyTests(unittest.TestCase):
    def test_updates_camera_and_resolution_preserving_other_config(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = Path(temporary_directory) / "config.ini"
            config.write_text(
                "[video]\n# keep me\ndevice_path = none\nframe_width = -1\n"
                "frame_height = -1\ntimeout = 10\n",
                encoding="utf-8",
            )

            MODULE.update_config(config, "/dev/video-ir")

            content = config.read_text(encoding="utf-8")
            self.assertIn("# keep me", content)
            self.assertIn("device_path = /dev/video-ir", content)
            self.assertIn("frame_width = 480", content)
            self.assertIn("frame_height = 480", content)
            self.assertIn("timeout = 10", content)

    def test_refuses_incomplete_config_without_writing_partial_changes(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            config = Path(temporary_directory) / "config.ini"
            original = "device_path = none\nframe_width = -1\n"
            config.write_text(original, encoding="utf-8")

            with self.assertRaises(ValueError):
                MODULE.update_config(config, "/dev/video-ir")

            self.assertEqual(config.read_text(encoding="utf-8"), original)


if __name__ == "__main__":
    unittest.main()
