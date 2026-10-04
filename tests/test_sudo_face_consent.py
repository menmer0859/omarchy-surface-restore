import errno
import os
import pty
import subprocess
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
        self.assertIn(b"controlling terminal", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
