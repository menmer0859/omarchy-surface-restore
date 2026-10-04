import importlib.util
import os
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/omarchy-polkit-howdy.py"


def load_module():
    spec = importlib.util.spec_from_file_location("omarchy_polkit_howdy", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PolkitHowdyWrapperTests(unittest.TestCase):
    def test_builds_argument_vector_for_the_selected_pam_account(self):
        self.assertTrue(SCRIPT.is_file(), "stdout-isolating Polkit Howdy helper is missing")
        command = load_module().command_for_user("eclipse")
        self.assertEqual(command, ["/usr/bin/python", "/usr/lib/howdy/compare.py", "eclipse"])

    def test_rejects_unknown_account_names(self):
        self.assertTrue(SCRIPT.is_file(), "stdout-isolating Polkit Howdy helper is missing")
        with self.assertRaises(KeyError):
            load_module().command_for_user("account-that-does-not-exist-omarchy-test")

    def test_invalid_pam_user_fails_without_writing_to_stdout(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            env={**os.environ, "PAM_USER": "account-that-does-not-exist-omarchy-test"},
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
