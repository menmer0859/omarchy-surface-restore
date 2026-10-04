import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets/omarchy-polkit"


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
