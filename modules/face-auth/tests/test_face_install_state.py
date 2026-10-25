import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/face-install-state.py"
SPEC = importlib.util.spec_from_file_location("face_install_state", SCRIPT)
state_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(state_module)


class FaceInstallStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "var/lib/omarchy-surface-restore/face-auth.json"

    def test_begin_records_package_baseline_and_reuses_original_transaction(self):
        first = state_module.begin(self.path, "alice", ["python-dlib-git"], "run-1", ["lock"])
        repeated = state_module.begin(self.path, "alice", [], "run-2", ["sudo"])
        self.assertEqual(first["id"], "run-1")
        self.assertEqual(repeated["id"], "run-1")
        self.assertEqual(repeated["packages_present_before"], ["python-dlib-git"])
        self.assertEqual(repeated["integrations"], ["lock", "sudo"])
        self.assertEqual(repeated["status"], "installing")

    def test_complete_and_uninstall_states_are_atomic_json_records(self):
        state_module.begin(self.path, "alice", ["howdy-git"], "run-1", ["lock"])
        state_module.set_status(self.path, "installed")
        self.assertEqual(json.loads(self.path.read_text())["status"], "installed")
        state_module.set_status(self.path, "uninstalling")
        self.assertEqual(json.loads(self.path.read_text())["status"], "uninstalling")
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_begin_rejects_a_different_user_or_untrusted_record(self):
        state_module.begin(self.path, "alice", [], "run-1", ["lock"])
        with self.assertRaises(ValueError):
            state_module.begin(self.path, "bob", [], "run-2", ["sudo"])
        self.path.write_text("not json")
        with self.assertRaises(ValueError):
            state_module.begin(self.path, "alice", [], "run-2", ["sudo"])

    def test_completed_uninstall_allows_a_fresh_transaction(self):
        state_module.begin(self.path, "alice", [], "run-1", ["lock"])
        state_module.set_status(self.path, "uninstalled")
        result = state_module.begin(self.path, "alice", [], "run-2", ["sudo"])
        self.assertEqual(result["id"], "run-2")
        self.assertEqual(result["integrations"], ["sudo"])

    def test_capture_and_verify_detect_user_changes_after_install(self):
        base = Path(self.temp.name)
        backup_root = base / "backups"
        snapshot = backup_root / "run-1"
        target = base / "target"
        path = target / "etc/pam.d/sudo"
        snapshot.mkdir(parents=True)
        path.parent.mkdir(parents=True)
        path.write_text("installed policy\n", encoding="utf-8")
        (snapshot / ".created_paths").write_text("/etc/pam.d/sudo\n", encoding="utf-8")
        (snapshot / ".backed_up_paths").write_text("", encoding="utf-8")
        state_module.begin(self.path, "alice", [], "run-1", ["sudo"])
        state_module.capture(self.path, backup_root, target)
        self.assertEqual(state_module.verify(self.path, backup_root, target), [])
        path.write_text("user-edited policy\n", encoding="utf-8")
        self.assertEqual(state_module.verify(self.path, backup_root, target), ["/etc/pam.d/sudo"])


if __name__ == "__main__":
    unittest.main()
