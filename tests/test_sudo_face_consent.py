import errno
import os
import pty
import select
import subprocess
import time
import unittest
import tempfile
import shutil
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "sudo-face-consent"


def run_with_controlling_tty(answer: bytes | None, helper=HELPER, prompt=b"Use face authentication? [y/N]", extra_env=None) -> tuple[int, bytes]:
    child, terminal = pty.fork()
    if child == 0:
        os.environ.update(extra_env or {})
        os.environ["PAM_USER"] = "surface-face-test-nonexistent-account"
        os.execv(helper, [str(helper)])

    output = bytearray()
    try:
        while prompt not in output:
            try:
                chunk = os.read(terminal, 1024)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not chunk:
                break
            output.extend(chunk)
        if prompt in output and answer is not None:
            os.write(terminal, answer)
        while True:
            try:
                chunk = os.read(terminal, 1024)
                if not chunk:
                    break
                output.extend(chunk)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
    finally:
        os.close(terminal)

    _, status = os.waitpid(child, 0)
    return os.waitstatus_to_exitcode(status), bytes(output)


def run_with_pam_tty_without_controlling_tty(answer: bytes) -> tuple[int, bytes]:
    child, terminal = pty.fork()
    if child == 0:
        env = os.environ.copy()
        env["PAM_USER"] = "surface-face-test-nonexistent-account"
        env["PAM_TTY"] = os.ttyname(0).removeprefix("/dev/")
        process = subprocess.Popen(
            [str(HELPER)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            start_new_session=True,
        )
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        os._exit(process.returncode)

    output = bytearray()
    prompt = b"Use face authentication? [y/N]"
    try:
        deadline = time.monotonic() + 2
        while prompt not in output and time.monotonic() < deadline:
            ready, _, _ = select.select([terminal], [], [], 0.1)
            if not ready:
                continue
            try:
                output.extend(os.read(terminal, 1024))
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
        if prompt in output:
            os.write(terminal, answer)
        _, status = os.waitpid(child, 0)
    finally:
        os.close(terminal)

    return os.waitstatus_to_exitcode(status), bytes(output)


class SudoFaceConsentTests(unittest.TestCase):
    def test_hostile_path_cannot_select_a_locale_program(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory); fake=base/'bin'; fake.mkdir(); attacker=base/'attacker'; attacker.mkdir()
            marker=base/'executed'
            (fake/'dirname').write_text('#!/bin/bash\nprintf "%s\\n" "'+str(attacker)+'"\n')
            (fake/'dirname').chmod(0o755)
            (attacker/'omarchy-face-auth-locale').write_text("from pathlib import Path\nPath("+repr(str(marker))+").touch()\nprint('Use face authentication? [y/N] ',end='')\n")
            code, output=run_with_controlling_tty(b'n\n',extra_env={'PATH':str(fake)+':'+os.environ['PATH']})
            self.assertNotEqual(code,0)
            self.assertFalse(marker.exists(), 'inherited PATH selected executable code')

    def test_chinese_prompt_and_guidance_on_a_real_terminal(self):
        # Substitute only the locale provider so this test never edits the host's
        # language preference. Its real parser/catalog behavior has separate tests.
        with tempfile.TemporaryDirectory() as directory:
            helper = Path(directory) / "sudo-face-consent"
            shutil.copy2(HELPER, helper)
            provider = Path(directory) / "omarchy-face-auth-locale"
            catalogs = HELPER.parent.parent / "assets/face-ui/i18n/zh-CN.json"
            provider.write_text("import json,sys\nfrom pathlib import Path\n"
                + "data=json.loads(Path(" + repr(str(catalogs)) + ").read_text())\n"
                + "print(data['face.hint' if '--key' in sys.argv else 'terminal.prompt'],end='')\n")
            code, output = run_with_controlling_tty(b"y\n", helper, "使用人脸识别？[y/N]".encode())
            self.assertEqual(code, 0)
            self.assertIn("笔记本".encode(), output)
            code, output = run_with_controlling_tty(b"n\n", helper, "使用人脸识别？[y/N]".encode())
            self.assertNotEqual(code, 0)
            self.assertNotIn("笔记本".encode(), output)

    def test_only_explicit_y_or_uppercase_y_accepts(self):
        for answer in (b"y\n", b"Y\n"):
            with self.subTest(answer=answer):
                exit_code, output = run_with_controlling_tty(answer)
                self.assertEqual(exit_code, 0)
                self.assertIn(b"Use face authentication? [y/N]", output)
                self.assertEqual(output.count(b"Use face authentication? [y/N]"), 1)

    def test_decline_and_other_inputs_do_not_accept_face_auth(self):
        for answer in (b"n\n", b"\n", b"yes\n"):
            with self.subTest(answer=answer):
                exit_code, output = run_with_controlling_tty(answer)
                self.assertNotEqual(exit_code, 0)
                self.assertIn(b"Use face authentication? [y/N]", output)
                self.assertEqual(output.count(b"Use face authentication? [y/N]"), 1)

    def test_consent_timeout_defaults_to_password_path(self):
        exit_code, output = run_with_controlling_tty(None)

        self.assertNotEqual(exit_code, 0)
        self.assertEqual(output.count(b"Use face authentication? [y/N]"), 1)

    def test_missing_controlling_tty_fails_closed(self):
        result = subprocess.run(
            [str(HELPER)],
            input=b"y\n",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"terminal", result.stderr.lower())

    def test_pam_tty_works_after_pam_exec_starts_a_new_session(self):
        exit_code, output = run_with_pam_tty_without_controlling_tty(b"N\n")

        self.assertNotEqual(exit_code, 0)
        self.assertIn(b"Use face authentication? [y/N]", output)
        self.assertEqual(output.count(b"Use face authentication? [y/N]"), 1)

    def test_explicit_consent_works_after_pam_exec_starts_a_new_session(self):
        exit_code, output = run_with_pam_tty_without_controlling_tty(b"y\n")

        self.assertEqual(exit_code, 0)
        self.assertIn(b"Use face authentication? [y/N]", output)


if __name__ == "__main__":
    unittest.main()
