import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "configure-polkit-pam.py"
SPEC = importlib.util.spec_from_file_location("configure_polkit_pam", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


POLKIT_CONFIG = (
    "#%PAM-1.0\n"
    "auth       include      system-auth\n"
    "account    include      system-auth\n"
    "password   include      system-auth\n"
    "session    include      system-auth\n"
)

SYSTEM_AUTH = (
    "#%PAM-1.0\n"
    "auth required pam_faillock.so preauth silent deny=10 unlock_time=120\n"
    "auth [success=1 default=bad] pam_unix.so try_first_pass nullok\n"
    "auth [default=die] pam_faillock.so authfail deny=10 unlock_time=120\n"
    "auth required pam_faillock.so authsucc\n"
)


class ConfigurePolkitPamTests(unittest.TestCase):
    def test_inserts_face_consent_howdy_and_password_fallback(self):
        result = MODULE.render_polkit_pam(POLKIT_CONFIG, SYSTEM_AUTH)

        self.assertIn("auth requisite pam_faillock.so preauth silent deny=10 unlock_time=120\n", result)
        self.assertIn("auth [success=ok default=2] /usr/local/lib/security/pam_surface_face_consent.so\n", result)
        self.assertIn("auth [success=ok default=1] pam_exec.so quiet seteuid /usr/local/libexec/omarchy-polkit-howdy\n", result)
        self.assertNotIn("pam_howdy.so", result)
        self.assertIn("auth [success=done default=die] pam_faillock.so authsucc\n", result)
        self.assertLess(result.index("pam_surface_face_consent.so"), result.index("omarchy-polkit-howdy"))
        self.assertLess(result.index("omarchy-polkit-howdy"), result.index("auth       include      system-auth"))
        self.assertEqual(result.count("include      system-auth"), 4)
        self.assertIn("account    include      system-auth\n", result)
        self.assertIn("password   include      system-auth\n", result)
        self.assertIn("session    include      system-auth\n", result)

    def test_is_idempotent(self):
        once = MODULE.render_polkit_pam(POLKIT_CONFIG, SYSTEM_AUTH)
        twice = MODULE.render_polkit_pam(once, SYSTEM_AUTH)
        self.assertEqual(twice, once)
        self.assertEqual(twice.count("omarchy-polkit-howdy"), 1)

    def test_refuses_missing_or_ambiguous_system_auth_rules(self):
        invalid = (
            SYSTEM_AUTH.replace(" preauth silent deny=10 unlock_time=120", ""),
            SYSTEM_AUTH.replace("auth required pam_faillock.so authsucc\n", ""),
            SYSTEM_AUTH.replace(
                "auth required pam_faillock.so authsucc\n",
                "auth required pam_faillock.so authsucc\nauth required pam_faillock.so authsucc\n",
            ),
        )
        for stack in invalid:
            with self.subTest(stack=stack), self.assertRaises(ValueError):
                MODULE.render_polkit_pam(POLKIT_CONFIG, stack)

    def test_refuses_additional_auth_rules_after_password_include(self):
        config = POLKIT_CONFIG + "auth required pam_u2f.so cue\n"
        with self.assertRaisesRegex(ValueError, "auth rules after the system-auth include"):
            MODULE.render_polkit_pam(config, SYSTEM_AUTH)

    def test_refuses_missing_ambiguous_or_unmanaged_face_rules(self):
        invalid = (
            POLKIT_CONFIG.replace("auth       include      system-auth\n", ""),
            POLKIT_CONFIG.replace(
                "auth       include      system-auth\n",
                "auth       include      system-auth\nauth       include      system-auth\n",
            ),
            POLKIT_CONFIG.replace(
                "auth       include      system-auth\n",
                "auth sufficient pam_howdy.so\nauth       include      system-auth\n",
            ),
        )
        for stack in invalid:
            with self.subTest(stack=stack), self.assertRaises(ValueError):
                MODULE.render_polkit_pam(stack, SYSTEM_AUTH)

    def test_cli_check_does_not_change_service_file(self):
        with tempfile.TemporaryDirectory() as directory:
            service = Path(directory) / "polkit-1"
            system_auth = Path(directory) / "system-auth"
            service.write_text(POLKIT_CONFIG, encoding="utf-8")
            system_auth.write_text(SYSTEM_AUTH, encoding="utf-8")
            before = service.read_text(encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(service), str(system_auth), "--check"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pam_surface_face_consent.so", result.stdout)
            self.assertEqual(service.read_text(encoding="utf-8"), before)


if __name__ == "__main__":
    unittest.main()
