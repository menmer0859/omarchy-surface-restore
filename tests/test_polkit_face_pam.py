import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PolkitFacePamTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.driver = Path(cls.temp.name) / "pam_consent_unit"
        subprocess.run(
            [
                "cc",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-o",
                str(cls.driver),
                str(ROOT / "tests/test_pam_consent_module.c"),
            ],
            check=True,
            capture_output=True,
            text=True,
        )

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_module(self, answer, *, conversation_fails=False):
        result = subprocess.run(
            [str(self.driver), answer, "1" if conversation_fails else "0"],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout

    def test_explicit_yes_returns_success_and_uses_visible_yes_no_prompt(self):
        output = self.run_module("y")
        self.assertIn("AUTH_RESULT=0", output)
        self.assertIn("PROMPT_STYLE=2", output)
        self.assertIn("PROMPT_TEXT=Use face authentication? [y/N]", output)

    def test_uppercase_y_also_consents(self):
        self.assertIn("AUTH_RESULT=0", self.run_module("Y"))

    def test_decline_empty_and_unrecognized_answers_return_ignore(self):
        for answer in ("", "n", "N", "yes", "Y "):
            with self.subTest(answer=answer):
                self.assertIn("AUTH_RESULT=25", self.run_module(answer))

    def test_conversation_error_returns_ignore_so_stack_can_fall_back(self):
        output = self.run_module("y", conversation_fails=True)
        self.assertIn("AUTH_RESULT=25", output)
        self.assertIn("PROMPT_STYLE=2", output)


if __name__ == "__main__":
    unittest.main()
