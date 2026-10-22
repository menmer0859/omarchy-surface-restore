import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]

class DeployUiTests(unittest.TestCase):
    def module(self):
        path = ROOT / 'modules/face-auth/scripts/deploy-face-ui.py'
        self.assertTrue(path.is_file(), 'resource deployer is required')
        spec = importlib.util.spec_from_file_location('deploy_ui', path)
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        return module

    def test_deploys_both_catalogs_and_resolves_shared_components_without_symlinks(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as directory:
            plugin = Path(directory) / 'plugin'
            module.deploy(ROOT / 'modules/face-auth', plugin, 'lock')
            self.assertTrue((plugin/'Service.qml').is_file())
            self.assertIn('Commons.Translations', (plugin/'FaceUi/AuthStrings.qml').read_text())
            self.assertIn('使用人脸', (plugin/'i18n/zh-CN.json').read_text())
            self.assertFalse(any(p.is_symlink() for p in plugin.rglob('*')))
            (plugin/'i18n/en.json').write_text('outdated')
            module.deploy(ROOT / 'modules/face-auth', plugin, 'lock')
            self.assertIn('Use face', (plugin/'i18n/en.json').read_text())

    def test_non_directory_component_parent_is_rejected_before_writing(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as directory:
            plugin = Path(directory)
            (plugin/'FaceUi').write_text('a file blocks the component directory')
            with self.assertRaises(ValueError): module.deploy(ROOT / 'modules/face-auth', plugin, 'lock')
            self.assertFalse((plugin/'Service.qml').exists())

    def test_polkit_resources_include_the_new_view_and_do_not_replace_manifest(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as directory:
            plugin = Path(directory)
            (plugin/'manifest.json').write_text('preserve clone metadata')
            module.deploy(ROOT / 'modules/face-auth', plugin, 'polkit')
            self.assertTrue((plugin/'AuthorizationView.qml').is_file())
            self.assertEqual((plugin/'manifest.json').read_text(), 'preserve clone metadata')

    def test_destination_symlinks_are_rejected_before_any_write(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); plugin = root/'plugin'; plugin.mkdir()
            outside = root/'outside'; outside.mkdir()
            (plugin/'FaceUi').symlink_to(outside, target_is_directory=True)
            with self.assertRaises(ValueError): module.deploy(ROOT / 'modules/face-auth', plugin, 'lock')
            self.assertFalse((plugin/'Service.qml').exists())
            self.assertEqual(list(outside.iterdir()), [])

if __name__ == '__main__': unittest.main()
