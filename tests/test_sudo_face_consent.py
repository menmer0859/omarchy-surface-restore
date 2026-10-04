import errno
import os
import pty
import select
import subprocess
import time
import unittest
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "sudo-face-consent"


def run_with_controlling_tty(answer: bytes) -> tuple[int, bytes]:
    child, terminal = pty.fork()
    if child == 0:
        os.execv(HELPER, [str(HELPER)])

    output = bytearray()
    try:
        prompt = b"Use face authentication? [y/N]"
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
        if prompt in output:
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
    def test_only_explicit_y_or_uppercase_y_accepts(self):
        for answer in (b"y\n", b"Y\n"):
            with self.subTest(answer=answer):
                exit_code, output = run_with_controlling_tty(answer)
                self.assertEqual(exit_code, 0)
                self.assertIn(b"Use face authentication? [y/N]", output)

    def test_decline_and_other_inputs_do_not_accept_face_auth(self):
        for answer in (b"n\n", b"\n", b"yes\n"):
            with self.subTest(answer=answer):
                exit_code, output = run_with_controlling_tty(answer)
                self.assertNotEqual(exit_code, 0)
                self.assertIn(b"Use face authentication? [y/N]", output)

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

    def test_explicit_consent_works_after_pam_exec_starts_a_new_session(self):
        exit_code, output = run_with_pam_tty_without_controlling_tty(b"y\n")

        self.assertEqual(exit_code, 0)
        self.assertIn(b"Use face authentication? [y/N]", output)


if __name__ == "__main__":
    unittest.main()
