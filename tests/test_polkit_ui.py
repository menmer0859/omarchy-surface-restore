import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets/omarchy-polkit"


def qml_function(source, name):
    marker = f"function {name}("
    start = source.find(marker)
    if start < 0:
        raise AssertionError(f"missing function {name}")
    opening = source.find("{", start + len(marker))
    depth = 0
    quote = None
    escaped = False
    for index in range(opening, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "'\"":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"unclosed function {name}")


class PolkitUiTests(unittest.TestCase):
    def test_plugin_maps_explicit_choices_to_the_pam_conversation(self):
        source = (ASSET / "PolkitAgent.qml").read_text(encoding="utf-8")
        self.assertIn("PolkitModel.isFaceConsentPrompt(currentPrompt)", source)
        self.assertIn('text: "Use face"', source)
        self.assertIn('text: "Use password"', source)
        self.assertIn('flow.submit(useFace ? "y" : "n")', source)
        self.assertIn("Looking for your face…", source)

    def test_prompt_classifier_matches_only_our_consent_message(self):
        result = subprocess.run(
            [
                "node",
                "-e",
                "const m=require(process.argv[1]);"
                "if(!m.isFaceConsentPrompt('Use face authentication? [y/N]')) process.exit(1);"
                "if(m.isFaceConsentPrompt('Password:')) process.exit(2);"
                "if(m.isFaceConsentPrompt('Use face authentication? [y/N] extra')) process.exit(3);",
                str(ASSET / "PolkitModel.js"),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_opening_a_cached_or_new_dialog_never_starts_face_without_consent(self):
        source = (ASSET / "PolkitAgent.qml").read_text(encoding="utf-8")
        begin = qml_function(source, "beginFlow")
        sync = qml_function(source, "syncFromFlow")
        submit = qml_function(source, "submitFaceConsent")
        self.assertNotIn("faceCheckPending = true", begin)
        self.assertNotIn("faceCheckPending = true", sync)
        self.assertIn("faceCheckPending = useFace", submit)
        self.assertIn('flow.submit(useFace ? "y" : "n")', submit)

    def test_face_failure_returns_to_an_editable_password_prompt(self):
        source = (ASSET / "PolkitAgent.qml").read_text(encoding="utf-8")
        feedback = qml_function(source, "triggerFailureFeedback")
        self.assertIn("faceFallbackActive = faceFallbackActive || faceCheckPending", feedback)
        self.assertIn("faceCheckPending = false", feedback)
        self.assertIn("!faceFallbackActive", source)
        self.assertIn('"Face recognition failed. Enter password."', source)
        self.assertIn("readOnly: root.submitted || root.errorFlash", source)
        self.assertIn("onTriggered: root.errorFlash = false", source)

    def test_face_failure_keeps_the_current_polkit_identity(self):
        source = (ASSET / "PolkitAgent.qml").read_text(encoding="utf-8")
        feedback = qml_function(source, "triggerFailureFeedback")
        consent = qml_function(source, "submitFaceConsent")
        self.assertIn("polkitAgent.flow", consent)
        self.assertNotIn("selectedIdentity =", feedback)
        self.assertIn("flow.selectedIdentity = flow.identities[index]", source)

    def test_identity_is_displayed_and_user_can_choose_another_polkit_identity(self):
        source = (ASSET / "PolkitAgent.qml").read_text(encoding="utf-8")
        self.assertIn("flow.selectedIdentity", source)
        self.assertIn("flow.identities", source)
        self.assertIn("PolkitModel.identityLabel", source)
        self.assertIn("flow.selectedIdentity =", source)

    def test_identity_label_disambiguates_users_and_groups(self):
        result = subprocess.run(
            [
                "node",
                "-e",
                "const m=require(process.argv[1]);"
                "if(typeof m.identityLabel!=='function') process.exit(3);"
                "if(m.identityLabel({isGroup:false,name:'eclipse',displayName:'Eclipse User'})!=='Eclipse User (eclipse)') process.exit(1);"
                "if(m.identityLabel({isGroup:true,name:'wheel',displayName:'wheel'})!=='Group: wheel') process.exit(2);",
                str(ASSET / "PolkitModel.js"),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
