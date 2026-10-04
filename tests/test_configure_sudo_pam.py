import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "configure-sudo-pam.py"
SPEC = importlib.util.spec_from_file_location("configure_sudo_pam", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


SUDO_CONFIG = (
    "#%PAM-1.0\n"
    "auth\t\tinclude\t\tsystem-auth\n"
    "account\t\tinclude\t\tsystem-auth\n"
    "session\t\tinclude\t\tsystem-auth\n"
    "session\t\toptional\tpam_systemd.so class=none\n"
)

SYSTEM_AUTH = (
    "#%PAM-1.0\n"
    "auth required pam_faillock.so preauth silent deny=10 unlock_time=120\n"
    "auth [success=1 default=bad] pam_unix.so try_first_pass nullok\n"
    "auth [default=die] pam_faillock.so authfail deny=10 unlock_time=120\n"
    "auth required pam_faillock.so authsucc\n"
)


class ConfigureSudoPamTests(unittest.TestCase):
    def test_adds_consent_gated_howdy_and_preserves_password_account_and_session_rules(self):
        result = MODULE.render_sudo_pam(SUDO_CONFIG, SYSTEM_AUTH)

        self.assertIn(
            "auth requisite pam_faillock.so preauth silent deny=10 unlock_time=120\n",
            result,
        )
        self.assertIn(
            "auth [success=ok default=2] pam_exec.so quiet /usr/local/libexec/omarchy-sudo-face-consent\n",
            result,
        )
        self.assertIn("auth [success=ok default=1] pam_howdy.so\n", result)
        self.assertIn("auth [success=done default=die] pam_faillock.so authsucc\n", result)
        self.assertLess(result.index("pam_exec.so"), result.index("pam_howdy.so"))
        self.assertLess(result.index("pam_howdy.so"), result.index("pam_faillock.so authsucc"))
        self.assertLess(result.index("pam_faillock.so authsucc"), result.index("include\t\tsystem-auth"))
        self.assertEqual(result.count("include\t\tsystem-auth"), 3)
        self.assertIn("account\t\tinclude\t\tsystem-auth\n", result)
        self.assertIn("session\t\tinclude\t\tsystem-auth\n", result)
        self.assertIn("session\t\toptional\tpam_systemd.so class=none\n", result)

    def test_is_idempotent(self):
        once = MODULE.render_sudo_pam(SUDO_CONFIG, SYSTEM_AUTH)

        twice = MODULE.render_sudo_pam(once, SYSTEM_AUTH)

        self.assertEqual(twice, once)
        self.assertEqual(twice.count("pam_howdy.so"), 1)

    def test_refuses_missing_or_ambiguous_faillock_rules(self):
        invalid_stacks = (
            SYSTEM_AUTH.replace(" preauth silent deny=10 unlock_time=120", ""),
            SYSTEM_AUTH.replace(
                "auth required pam_faillock.so preauth silent deny=10 unlock_time=120\n",
                "auth required pam_faillock.so preauth silent deny=10 unlock_time=120\n"
                "auth required pam_faillock.so preauth silent deny=10 unlock_time=120\n",
            ),
            SYSTEM_AUTH.replace("auth required pam_faillock.so authsucc\n", ""),
        )
        for invalid in invalid_stacks:
            with self.subTest(stack=invalid):
                with self.assertRaises(ValueError):
                    MODULE.render_sudo_pam(SUDO_CONFIG, invalid)

    def test_refuses_missing_or_ambiguous_password_fallback(self):
        invalid_sudo_configs = (
            SUDO_CONFIG.replace("auth\t\tinclude\t\tsystem-auth\n", ""),
            SUDO_CONFIG.replace(
                "auth\t\tinclude\t\tsystem-auth\n",
                "auth\t\tinclude\t\tsystem-auth\n"
                "auth\t\tinclude\t\tsystem-auth\n",
            ),
            SUDO_CONFIG.replace(
                "auth\t\tinclude\t\tsystem-auth\n",
                "auth sufficient pam_howdy.so\n"
                "auth\t\tinclude\t\tsystem-auth\n",
            ),
        )
        for invalid in invalid_sudo_configs:
            with self.subTest(config=invalid):
                with self.assertRaises(ValueError):
                    MODULE.render_sudo_pam(invalid, SYSTEM_AUTH)

    def test_cli_writes_only_after_full_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            sudo_file = Path(directory) / "sudo"
            system_auth_file = Path(directory) / "system-auth"
            sudo_file.write_text(SUDO_CONFIG, encoding="utf-8")
            system_auth_file.write_text(SYSTEM_AUTH, encoding="utf-8")

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(sudo_file), str(system_auth_file)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            configured = sudo_file.read_text(encoding="utf-8")
            self.assertIn("pam_howdy.so", configured)

            before_invalid_run = configured
            system_auth_file.write_text("# no faillock rules\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(sudo_file), str(system_auth_file)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(sudo_file.read_text(encoding="utf-8"), before_invalid_run)


if __name__ == "__main__":
    unittest.main()
