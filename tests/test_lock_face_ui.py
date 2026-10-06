import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "assets/omarchy-lock"


def qml_block(source, marker, occurrence=1):
    """Return a balanced QML block beginning at marker, ignoring braces in strings/comments."""
    start = -1
    search_from = 0
    for _ in range(occurrence):
        start = source.find(marker, search_from)
        if start < 0:
            raise AssertionError(f"missing QML block: {marker}")
        search_from = start + len(marker)
    opening = source.find("{", start + len(marker))
    if opening < 0:
        raise AssertionError(f"missing opening brace for: {marker}")
    depth = 0
    quote = None
    escaped = False
    line_comment = False
    block_comment = False
    i = opening
    while i < len(source):
        char = source[i]
        following = source[i + 1] if i + 1 < len(source) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
        elif block_comment:
            if char == "*" and following == "/":
                block_comment = False
                i += 1
        elif quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "'\"":
            quote = char
        elif char == "/" and following == "/":
            line_comment = True
            i += 1
        elif char == "/" and following == "*":
            block_comment = True
            i += 1
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : i + 1]
        i += 1
    raise AssertionError(f"unclosed QML block: {marker}")


class LockFaceUiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.service = (LOCK / "Service.qml").read_text(encoding="utf-8")
        cls.view = (LOCK / "LockView.qml").read_text(encoding="utf-8")

    def test_secure_config_and_preview_paths_do_not_start_face_authentication(self):
        secure = qml_block(self.service, "onSecureStateChanged:")
        face_check = qml_block(self.service, "id: faceCheckProc")
        begin_lock = qml_block(self.service, "function beginLock()")
        preview = qml_block(self.service, "LockView {", occurrence=2)
        self.assertNotIn("startFace(", secure)
        self.assertNotIn('type: "INTENT"', secure)
        self.assertNotIn("startFace(", face_check)
        self.assertNotIn('type: "INTENT"', face_check)
        self.assertNotIn('type: "INTENT"', begin_lock)
        self.assertNotIn("onFaceIntentRequested", preview)

    def test_wake_and_face_intent_are_distinct_and_gestures_are_press_based(self):
        self.assertIn("signal wakeRequested", self.view)
        self.assertIn("signal faceIntentRequested", self.view)
        self.assertIn("signal faceRetryRequested", self.view)
        background = qml_block(self.view, "MouseArea {")
        self.assertIn("onPressed:", background)
        self.assertIn("root.requestFaceIntent()", background)
        self.assertRegex(self.view, r"onPositionChanged: root\.wakeRequested\(\)")
        self.assertNotIn("onReleased:", self.view)
        self.assertIn("Keys.onPressed:", self.view)
        self.assertRegex(self.view, r"onPositionChanged: root\.wakeRequested\(\)")
        position_handler = next(line for line in self.view.splitlines() if "onPositionChanged:" in line)
        self.assertNotIn("faceIntentRequested", position_handler)

    def test_tab_keys_remain_available_for_retry_and_password_focus(self):
        key_handler = qml_block(self.view, "Keys.onPressed:")
        self.assertIn("Qt.Key_Tab", key_handler)
        self.assertIn("Qt.Key_Backtab", key_handler)
        self.assertRegex(key_handler, r"if \(event\.key === Qt\.Key_Tab \|\| event\.key === Qt\.Key_Backtab\)\s+return")

    def test_blank_screen_pointer_motion_wakes_without_requesting_face_auth(self):
        self.assertIn("property bool displayBlanked: false", self.service, "display blank tracking must be present")
        blank = qml_block(self.service, "function runBlank()")
        wake = qml_block(self.service, "function handleWakeRequested()")
        self.assertIn("displayBlanked = true", blank, "blank action must record this plugin blanked the display")
        self.assertIn("runWake()", wake, "wake handler must wake the display")
        self.assertNotIn('type: "INTENT"', wake, "passive pointer entry and movement must never start face auth")
        intent = qml_block(self.view, "function requestFaceIntent()")
        self.assertIn("faceIntentRequested()", intent, "explicit key presses and pointer presses request face auth")

    def test_face_attempt_is_bounded_and_retry_is_explicit(self):
        self.assertNotIn("faceRetryTimer", self.service)
        self.assertIn("onFaceRetryRequested", self.service)
        timers = [qml_block(self.service, marker) for marker in ("id: faceAttemptTimer",)]
        self.assertEqual(len(timers), 1)
        self.assertIn("interval: 12000", timers[0])
        self.assertIn("repeat: false", timers[0])
        retry_button = qml_block(self.view, "id: faceRetryButton")
        self.assertIn('text: "重试人脸"', retry_button)
        self.assertIn("onClicked: root.faceRetryRequested()", self.view)

    def test_password_selection_and_submission_abort_face_before_authentication(self):
        mode = qml_block(self.service, "function setUnlockMode(mode)")
        submit = qml_block(self.service, "function submitPassword(value)")
        self.assertIn('type: "PASSWORD_SELECTED"', mode)
        self.assertIn('type: "PASSWORD_SELECTED"', submit)
        self.assertLess(submit.index('type: "PASSWORD_SELECTED"'), submit.index("passwordPam.start()"))
        self.assertIn("使用密码", self.view)
        self.assertIn("使用人脸", self.view)

    def test_each_pam_context_captures_its_generation_to_reject_late_callbacks(self):
        self.assertIn("facePamLockId", self.service)
        self.assertIn("facePamAttemptId", self.service)
        self.assertIn("facePamFactory.createObject(root)", self.service)
        self.assertIn("context.completed.connect(function (result)", self.service)
        self.assertIn("root.handleFaceFinished(result, lockId, attemptId, context)", self.service)
        self.assertIn("context !== activeFacePam", self.service)
        self.assertIn('type: "FACE_RESULT"', self.service)
        self.assertIn('type: "FACE_TIMEOUT"', self.service)
        self.assertIn('type: "SUSPEND"', self.service)
        self.assertIn("member=PrepareForSleep", self.service)
        self.assertIn("boolean true", self.service)
        process_start = self.service.rfind("Process {", 0, self.service.index("id: suspendEventProc"))
        suspend_monitor = qml_block(self.service[process_start:], "Process")
        self.assertIn("onExited: function (exitCode, exitStatus)", suspend_monitor)
        self.assertNotIn("onErrorOccurred", suspend_monitor)


if __name__ == "__main__":
    unittest.main()
